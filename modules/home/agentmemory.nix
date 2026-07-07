{ ... }: {
  flake.modules.homeManager.base = { config, pkgs, lib, ... }:
  let
    # agentmemory LoadBalancer endpoints on the LAN (shared Cilium IP, distinct ports).
    claudeURL = "http://192.168.1.120:3111"; # agentmemory-claude (Claude Code, Codex)
    qwenURL = "http://192.168.1.120:3211"; # agentmemory-qwen (Qwen Code, Crush, OpenCode)

    claudeTokenFile = config.sops.secrets."agentmemory/claude-token".path;
    qwenTokenFile = config.sops.secrets."agentmemory/qwen-token".path;

    # --- MCP bridge launchers ---------------------------------------------------
    # `@agentmemory/mcp` is a local stdio bridge each client spawns (via npx); it
    # reads AGENTMEMORY_URL + AGENTMEMORY_SECRET from its env and forwards to the
    # remote engine on the cluster. Instead of baking the bearer token into every
    # client config, each client launches one of these wrappers, which reads the
    # token from the sops file at spawn time — so the secret never lands in any
    # client config file. One wrapper per instance (distinct URL + bearer token):
    # the claude instance (Claude Code, Codex) and the qwen instance (Qwen, Crush,
    # OpenCode).
    mkMcpWrapper = name: url: tokenFile: pkgs.writeShellScriptBin name ''
      set -eu
      export PATH="${pkgs.nodejs}/bin:''${PATH:-/usr/bin:/bin}"
      export AGENTMEMORY_URL="${url}"
      if [ -r "${tokenFile}" ]; then
        AGENTMEMORY_SECRET="$(cat "${tokenFile}")"
        export AGENTMEMORY_SECRET
      else
        echo "${name}: ${tokenFile} not readable; agentmemory MCP starting unauthenticated" >&2
      fi
      exec ${pkgs.nodejs}/bin/npx -y @agentmemory/mcp "$@"
    '';
    mcpClaude = mkMcpWrapper "agentmemory-mcp-claude" claudeURL claudeTokenFile;
    mcpQwen = mkMcpWrapper "agentmemory-mcp-qwen" qwenURL qwenTokenFile;
    claudeMcpBin = "${mcpClaude}/bin/agentmemory-mcp-claude";
    qwenMcpBin = "${mcpQwen}/bin/agentmemory-mcp-qwen";

    # Per-agent jq programs that set only the agentmemory MCP entry — command is
    # the launcher above, no embedded secret. Assigning the whole object replaces
    # any previously-embedded `env`/token. `bin` is baked in by Nix, so the merge
    # needs no jq --arg.
    mcpServersProg = bin: ''.mcpServers.agentmemory = {command: "${bin}", args: []}'';
    crushProg = bin: ''.["$schema"] = "https://charm.land/crush.json" | .mcp.agentmemory = {type: "stdio", command: "${bin}", args: []}'';
    opencodeProg = bin: ''.["$schema"] = "https://opencode.ai/config.json" | .mcp.agentmemory = {type: "local", command: ["${bin}"], enabled: true}'';

    # --- Lifecycle hooks + skills (Claude Code & Codex) -----------------------

    # Pinned to the version the memory server runs (the StatefulSet's npm pin).
    # Bump this in lockstep with the cluster image so the hook scripts' REST
    # contract matches the running engine.
    agentmemoryVersion = "0.9.26";

    # The hook scripts are dependency-free Node (they import nothing and use the
    # global fetch), so there is no npm install — just unpack the published
    # tarball into an immutable store path. A stable path means upgrades never
    # silently break the hook commands the way version-embedded cache paths do
    # (their issue #508): the path only changes on a deliberate version bump.
    agentmemoryPlugin = pkgs.stdenvNoCC.mkDerivation {
      pname = "agentmemory-plugin";
      version = agentmemoryVersion;
      src = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@agentmemory/agentmemory/-/agentmemory-${agentmemoryVersion}.tgz";
        hash = "sha256-h6SMbE4ELw91wQEh+zEJZ8XOd67+kWRbDXh6VWQdRTI=";
      };
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -r plugin/scripts "$out/scripts"
        cp -r plugin/skills "$out/skills"
        runHook postInstall
      '';
    };

    # One wrapper for every lifecycle hook. It reads the bearer token from the
    # sops secret at run time so the token never lands in any agent config, points
    # at the claude instance, and asks for context injection only on the two
    # cheap, high-value events (session start and pre-compact). PreToolUse is
    # deliberately not wired: that script is injection-only — a no-op without
    # injection — and PostToolUse already records tool activity.
    agentmemoryHook = pkgs.writeShellScriptBin "agentmemory-hook" ''
      set -euo pipefail
      hook="''${1:?usage: agentmemory-hook <hook-name>}"
      export PATH="${pkgs.git}/bin:${pkgs.nodejs}/bin:''${PATH:-/usr/bin:/bin}"
      export AGENTMEMORY_URL="${claudeURL}"
      export AGENTMEMORY_TOOLS="all"
      case "$hook" in
        session-start|pre-compact) export AGENTMEMORY_INJECT_CONTEXT="true" ;;
      esac
      if [ -r "${claudeTokenFile}" ]; then
        AGENTMEMORY_SECRET="$(cat "${claudeTokenFile}")"
        export AGENTMEMORY_SECRET
      else
        echo "agentmemory-hook: ${claudeTokenFile} not readable; running unauthenticated" >&2
      fi
      exec ${pkgs.nodejs}/bin/node "${agentmemoryPlugin}/scripts/$hook.mjs"
    '';

    hookCmd = script: "${agentmemoryHook}/bin/agentmemory-hook ${script}";
    mkHook = script: [ { hooks = [ { type = "command"; command = hookCmd script; } ]; } ];

    # SessionStart injection sourced FROM agentmemory (the single source of truth),
    # for BOTH agents. The three standing directives — §0 north star, §10 commits,
    # §11 memory usage — are tagged with the `inject:session-start` facet, so this
    # hook fetches ONLY those three: one facet-query for their ids, then a by-id GET
    # each (it never scans the whole store). Their content is written to stdout,
    # which Claude Code and Codex fold into session context (same mechanism the
    # plugin uses). Fail-open: any error → exit 0, session start is never blocked.
    directiveInject = pkgs.writeShellScript "agentmemory-inject-directives" ''
      set -eu
      export PATH="${pkgs.curl}/bin:${pkgs.jq}/bin:''${PATH:-/usr/bin:/bin}"
      [ -r "${claudeTokenFile}" ] || exit 0
      tok="$(cat "${claudeTokenFile}")"; [ -n "$tok" ] || exit 0
      u="${claudeURL}/agentmemory"
      ids="$(curl -s --max-time 2 -X POST -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' \
        -d '{"matchAll":["inject:session-start"],"targetType":"memory"}' "$u/facets/query" \
        | jq -r '.results[]?.targetId' 2>/dev/null)" || exit 0
      [ -n "$ids" ] || exit 0
      ctx="$(for id in $ids; do curl -s --max-time 2 -H "Authorization: Bearer $tok" "$u/memories/$id"; done \
        | jq -rs 'sort_by(.memory.title) | map(.memory.content) | join("\n\n")' 2>/dev/null)" || exit 0
      [ -n "$ctx" ] && printf '# Standing directives (recalled from agentmemory)\n\n%s\n' "$ctx"
      exit 0
    '';
    injectEntry = [ { hooks = [ { type = "command"; command = "${directiveInject}"; } ]; } ];

    # Claude Code: every host lifecycle event except PreToolUse (see above).
    claudeHooks = {
      SessionStart = mkHook "session-start" ++ injectEntry;
      UserPromptSubmit = mkHook "prompt-submit";
      PostToolUse = mkHook "post-tool-use";
      PostToolUseFailure = mkHook "post-tool-failure";
      PreCompact = mkHook "pre-compact";
      SubagentStart = mkHook "subagent-start";
      SubagentStop = mkHook "subagent-stop";
      Notification = mkHook "notification";
      TaskCompleted = mkHook "task-completed";
      Stop = mkHook "stop";
      SessionEnd = mkHook "session-end";
    };

    # Codex dispatches a smaller lifecycle set; PreToolUse omitted as above.
    codexHooks = {
      SessionStart = mkHook "session-start" ++ injectEntry;
      UserPromptSubmit = mkHook "prompt-submit";
      PostToolUse = mkHook "post-tool-use";
      PreCompact = mkHook "pre-compact";
      Stop = mkHook "stop";
    };

    codexHooksJson = builtins.toJSON codexHooks;

    # Idempotent, non-destructive merge into a host's hooks map: for each event we
    # own, drop any prior agentmemory entry (matched by the wrapper name, so a
    # stale store path from an earlier version is replaced) and append the current
    # one. Unrelated user hooks on the same event survive, as does every other
    # top-level settings key.
    hookMergeProg = ''
      .hooks = (.hooks // {})
      | reduce ($am | to_entries[]) as $e (.;
          .hooks[$e.key] = (
            (((.hooks[$e.key]) // [])
              | map(select(([ .hooks[]? | .command // "" ] | any(test("agentmemory-hook"))) | not)))
            + $e.value
          )
        )
    '';

    agentmemorySkills = [
      "remember" "recall" "recap" "handoff"
      "forget" "commit-context" "commit-history" "session-history"
    ];
    mkSkillLinks = dir: lib.listToAttrs (map (s: {
      name = "${dir}/${s}";
      value.source = "${agentmemoryPlugin}/skills/${s}";
    }) agentmemorySkills);
  in {
    # Claude Code lifecycle hooks, contributed declaratively to the list-merging
    # programs.claudeCode.hooks option that home/claude/claude.nix folds into
    # ~/.claude/settings.json (per-event lists concatenate across modules, so
    # home/claude/session-directives.nix can also append a SessionStart hook).
    # (Codex, whose config is TOML, still gets its hooks via the activation merge
    # below.)
    programs.claudeCode.hooks = claudeHooks;

    # Single source of truth for all agentmemory wiring — MCP servers, lifecycle
    # hooks, and skills, for every connected agent. JSON agents are jq-merged in
    # place; Codex's MCP block is appended onto the base config that
    # home/codex.nix regenerates (hence the "codexConfig" ordering dependency).
    # No bearer token is written into any client config: each client launches a
    # wrapper that reads the token from the sops file at spawn time, so this
    # activation never touches the secret at all. Self-heals on every
    # `nixos-rebuild switch`.
    home.activation.agentmemory = lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" "codexConfig" ] ''
      am_merge() {
        local file="$1" prog="$2" base
        $DRY_RUN_CMD mkdir -p "$(dirname "$file")"
        if [ -f "$file" ]; then base="$(cat "$file")"; else base="{}"; fi
        if printf '%s' "$base" | ${pkgs.jq}/bin/jq "$prog" > "$file.am.tmp"; then
          $DRY_RUN_CMD mv -- "$file.am.tmp" "$file"
        else
          rm -f "$file.am.tmp"
          echo "agentmemory: jq merge failed for $file (left unchanged)" >&2
        fi
      }

      am_merge_hooks() {
        local file="$1" am="$2" base
        $DRY_RUN_CMD mkdir -p "$(dirname "$file")"
        if [ -f "$file" ]; then base="$(cat "$file")"; else base="{}"; fi
        if printf '%s' "$base" | ${pkgs.jq}/bin/jq --argjson am "$am" '${hookMergeProg}' > "$file.am.tmp"; then
          $DRY_RUN_CMD mv -- "$file.am.tmp" "$file"
        else
          rm -f "$file.am.tmp"
          echo "agentmemory: jq hook merge failed for $file (left unchanged)" >&2
        fi
      }

      # MCP servers (jq merge, non-destructive). The launcher reads the token from
      # sops at spawn time, so no secret is written here. Assigning the whole
      # agentmemory object also strips any token embedded by a previous version.
      am_merge "$HOME/.claude.json"                   ${lib.escapeShellArg (mcpServersProg claudeMcpBin)}
      am_merge "$HOME/.qwen/settings.json"            ${lib.escapeShellArg (mcpServersProg qwenMcpBin)}
      am_merge "$HOME/.config/crush/crush.json"       ${lib.escapeShellArg (crushProg qwenMcpBin)}
      am_merge "$HOME/.config/opencode/opencode.json" ${lib.escapeShellArg (opencodeProg qwenMcpBin)}

      # Codex (TOML): append the agentmemory block onto the base config that
      # home/codex.nix just regenerated. codexConfig strips any prior block (its awk
      # preserves only [projects.*]), so this re-adds it deterministically each run
      # — which is also how the previously-embedded [.env] secret table gets
      # dropped on the next switch. command is the launcher; no [.env], no secret.
      codex_toml="$HOME/.codex/config.toml"
      if [ ! -f "$codex_toml" ]; then
        echo "agentmemory: $codex_toml missing (codexConfig should create it), skipping codex" >&2
      elif ${pkgs.gnugrep}/bin/grep -q '^\[mcp_servers\.agentmemory\]' "$codex_toml"; then
        : # block already present (codexConfig normally strips it first, so this is the no-op guard)
      else
        {
          cat "$codex_toml"
          printf '\n[mcp_servers.agentmemory]\n'
          printf 'command = "%s"\n' "${claudeMcpBin}"
        } > "$codex_toml.am.tmp"
        $DRY_RUN_CMD mv -- "$codex_toml.am.tmp" "$codex_toml"
        $DRY_RUN_CMD chmod 600 "$codex_toml"
      fi

      # Codex lifecycle hooks (TOML client, no declarative home-manager surface, so
      # still a runtime jq-merge). Claude Code's hooks are now declarative — see the
      # programs.claudeCode.hooks contribution above. The wrapper reads the
      # bearer token at run time, so these are wired regardless of token state and
      # carry no secret in the file.
      am_merge_hooks "$HOME/.codex/hooks.json"     ${lib.escapeShellArg codexHooksJson}
    '';

    # agentmemory skills for Claude Code and Codex: read-only symlinks into the
    # pinned plugin. The slash commands (/remember, /recall, ...) come from each
    # skill's SKILL.md frontmatter name, not the directory name.
    home.file = (mkSkillLinks ".claude/skills") // (mkSkillLinks ".codex/skills");
  };
}
