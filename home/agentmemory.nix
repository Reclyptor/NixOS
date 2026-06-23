{ config, pkgs, lib, ... }:
let
  # agentmemory LoadBalancer endpoints on the LAN (shared Cilium IP, distinct ports).
  claudeURL = "http://192.168.1.120:3111"; # agentmemory-claude (Claude Code, Codex)
  qwenURL = "http://192.168.1.120:3211"; # agentmemory-qwen (Qwen Code, Crush, OpenCode)

  claudeTokenFile = config.sops.secrets."agentmemory/claude-token".path;
  qwenTokenFile = config.sops.secrets."agentmemory/qwen-token".path;

  # Per-agent jq programs that set only the agentmemory MCP entry and leave the rest
  # of each config untouched. $url/$tok are supplied via `jq --arg`. The two instances
  # use different bearer tokens, so the token is baked into each agent's env block.
  mcpServersProg = ''.mcpServers.agentmemory = {command: "npx", args: ["-y", "@agentmemory/mcp"], env: {AGENTMEMORY_URL: $url, AGENTMEMORY_SECRET: $tok}}'';
  crushProg = ''.["$schema"] = "https://charm.land/crush.json" | .mcp.agentmemory = {type: "stdio", command: "npx", args: ["-y", "@agentmemory/mcp"], env: {AGENTMEMORY_URL: $url, AGENTMEMORY_SECRET: $tok}}'';
  opencodeProg = ''.["$schema"] = "https://opencode.ai/config.json" | .mcp.agentmemory = {type: "local", command: ["npx", "-y", "@agentmemory/mcp"], environment: {AGENTMEMORY_URL: $url, AGENTMEMORY_SECRET: $tok}, enabled: true}'';

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

  # Claude Code: every host lifecycle event except PreToolUse (see above).
  claudeHooks = {
    SessionStart = mkHook "session-start";
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
    SessionStart = mkHook "session-start";
    UserPromptSubmit = mkHook "prompt-submit";
    PostToolUse = mkHook "post-tool-use";
    PreCompact = mkHook "pre-compact";
    Stop = mkHook "stop";
  };

  claudeHooksJson = builtins.toJSON claudeHooks;
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
  # Single source of truth for all agentmemory wiring — MCP servers, lifecycle
  # hooks, and skills, for every connected agent. JSON agents are jq-merged in
  # place; Codex's MCP block is appended onto the base config that
  # home/codex.nix regenerates (hence the "codexConfig" ordering dependency).
  # Runs after sops-nix so the bearer tokens are decrypted and on disk.
  # Self-heals on every `nixos-rebuild switch`.
  home.activation.agentmemory = lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" "codexConfig" ] ''
    am_merge() {
      local file="$1" prog="$2" url="$3" tok="$4" base
      if [ -z "$tok" ]; then
        echo "agentmemory: token empty, skipping $file" >&2
        return
      fi
      $DRY_RUN_CMD mkdir -p "$(dirname "$file")"
      if [ -f "$file" ]; then base="$(cat "$file")"; else base="{}"; fi
      if printf '%s' "$base" | ${pkgs.jq}/bin/jq --arg url "$url" --arg tok "$tok" "$prog" > "$file.am.tmp"; then
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

    claude_tok=""
    if [ -r "${claudeTokenFile}" ]; then claude_tok="$(cat "${claudeTokenFile}")"; fi
    qwen_tok=""
    if [ -r "${qwenTokenFile}" ]; then qwen_tok="$(cat "${qwenTokenFile}")"; fi
    if [ -z "$claude_tok" ]; then echo "agentmemory: ${claudeTokenFile} missing/empty — claude-instance agents not wired" >&2; fi
    if [ -z "$qwen_tok" ]; then echo "agentmemory: ${qwenTokenFile} missing/empty — qwen-instance agents not wired" >&2; fi

    # JSON agents (jq merge, non-destructive).
    am_merge "$HOME/.claude.json"                   ${lib.escapeShellArg mcpServersProg} "${claudeURL}" "$claude_tok"
    am_merge "$HOME/.qwen/settings.json"            ${lib.escapeShellArg mcpServersProg} "${qwenURL}"   "$qwen_tok"
    am_merge "$HOME/.config/crush/crush.json"       ${lib.escapeShellArg crushProg}      "${qwenURL}"   "$qwen_tok"
    am_merge "$HOME/.config/opencode/opencode.json" ${lib.escapeShellArg opencodeProg}   "${qwenURL}"   "$qwen_tok"

    # Codex (TOML): append the agentmemory block onto the base config that
    # home/codex.nix just regenerated. codexConfig strips any prior block (its awk
    # preserves only [projects.*]), so this re-adds it deterministically each run.
    codex_toml="$HOME/.codex/config.toml"
    if [ -z "$claude_tok" ]; then
      echo "agentmemory: token empty, skipping codex" >&2
    elif [ ! -f "$codex_toml" ]; then
      echo "agentmemory: $codex_toml missing (codexConfig should create it), skipping codex" >&2
    elif ${pkgs.gnugrep}/bin/grep -q '^\[mcp_servers\.agentmemory\]' "$codex_toml"; then
      : # an actual [mcp_servers.agentmemory] table header is already present
    else
      {
        cat "$codex_toml"
        printf '\n[mcp_servers.agentmemory]\n'
        printf 'command = "npx"\n'
        printf 'args = ["-y", "@agentmemory/mcp"]\n\n'
        printf '[mcp_servers.agentmemory.env]\n'
        printf 'AGENTMEMORY_URL = "%s"\n' "${claudeURL}"
        printf 'AGENTMEMORY_SECRET = "%s"\n' "$claude_tok"
      } > "$codex_toml.am.tmp"
      $DRY_RUN_CMD mv -- "$codex_toml.am.tmp" "$codex_toml"
      $DRY_RUN_CMD chmod 600 "$codex_toml"
    fi

    # Lifecycle hooks. The wrapper reads the bearer token at run time, so these
    # are wired regardless of token state and carry no secret in the file.
    am_merge_hooks "$HOME/.claude/settings.json" ${lib.escapeShellArg claudeHooksJson}
    am_merge_hooks "$HOME/.codex/hooks.json"     ${lib.escapeShellArg codexHooksJson}
  '';

  # agentmemory skills for Claude Code and Codex: read-only symlinks into the
  # pinned plugin. The slash commands (/remember, /recall, ...) come from each
  # skill's SKILL.md frontmatter name, not the directory name.
  home.file = (mkSkillLinks ".claude/skills") // (mkSkillLinks ".codex/skills");
}
