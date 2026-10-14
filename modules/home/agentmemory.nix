_: {
  flake.modules.homeManager.base =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # agentmemory LoadBalancer endpoint on the LAN (shared Cilium IP).
      agentmemoryURL = "http://192.168.1.120:3111";

      agentmemoryTokenFile = config.sops.secrets."agentmemory/claude-token".path;

      # --- MCP bridge launcher ----------------------------------------------------
      # `@agentmemory/mcp` is a local stdio bridge each client spawns; it reads
      # AGENTMEMORY_URL + AGENTMEMORY_SECRET from its env and forwards to the
      # remote engine on the cluster. Instead of baking the bearer token into every
      # client config, each client launches this wrapper, which reads the token from
      # the sops file at spawn time — so the secret never lands in any client config
      # file. A single engine now serves every agent, so one wrapper serves them all.
      mcpWrapper = pkgs.writeShellScriptBin "agentmemory-mcp" ''
        set -eu
        export PATH="${pkgs.nodejs}/bin:''${PATH:-/usr/bin:/bin}"
        export AGENTMEMORY_URL="${agentmemoryURL}"
        if [ -r "${agentmemoryTokenFile}" ]; then
          AGENTMEMORY_SECRET="$(cat "${agentmemoryTokenFile}")"
          export AGENTMEMORY_SECRET
        else
          echo "agentmemory-mcp: ${agentmemoryTokenFile} not readable; agentmemory MCP starting unauthenticated" >&2
        fi
        exec ${pkgs.nodejs}/bin/node ${agentmemoryMcp}/libexec/agentmemory-mcp/bin.mjs "$@"
      '';
      mcpBin = "${mcpWrapper}/bin/agentmemory-mcp";

      # --- Lifecycle hooks + skills (Claude Code & Codex) -----------------------

      # Pinned to what the memory server runs, so the hook scripts' REST
      # contract matches the running engine. The cluster image is built from
      # upstream commit agentmemoryCommit: v0.9.30 plus #1507, the fix for 0.9.30
      # completing a session at its first Stop (their issue #745), which no npm
      # release contains yet. The client side therefore pins in two halves, each
      # verified byte-identical to the image's own build:
      #   - plugin/ (hook scripts + skills) from GitHub at that commit; the repo
      #     commits the built plugin/scripts, and #1507 changes stop.mjs and
      #     session-end.mjs;
      #   - the MCP bridge's package from npm agentmemoryVersion, because the
      #     bridge needs dist/standalone.mjs, which only a build produces (it is
      #     unchanged by the commits past the release).
      # Once a release contains #1507, collapse both back into one npm pin and
      # move the cluster image to it in lockstep.
      agentmemoryCommit = "df3d4a83b966d8d415cb9180d5a4724b07f729dc";
      agentmemoryVersion = "0.9.30";

      # The hook scripts are dependency-free Node (they import only node:
      # builtins and each other and use the global fetch), so there is no npm
      # install. A stable path means upgrades never silently break the hook
      # commands the way version-embedded cache paths do (their issue #508):
      # the path only changes on a deliberate bump.
      agentmemoryPlugin = pkgs.fetchFromGitHub {
        owner = "rohitg00";
        repo = "agentmemory";
        rev = agentmemoryCommit;
        hash = "sha256-BEhWtstq08fRpfcHYr1r6aFZm3NfV3nVM23ixcQvsdI=";
      };

      # dist/standalone.mjs keeps one bare `import "picocolors"` that its bundler
      # left external, and Node resolves it from the importing file's real path,
      # so it has to sit in this package's own node_modules. Same version the
      # cluster image resolves.
      picocolors = pkgs.fetchzip {
        url = "https://registry.npmjs.org/picocolors/-/picocolors-1.1.1.tgz";
        hash = "sha256-rtRAUPawx8nY0GyspP/GmVhcNEitt6eO/dJ5hTe/5rw=";
      };

      # The published package, unpacked whole into an immutable store path, for
      # the MCP bridge's node_modules.
      agentmemoryPkg = pkgs.stdenvNoCC.mkDerivation {
        pname = "agentmemory";
        version = agentmemoryVersion;
        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/@agentmemory/agentmemory/-/agentmemory-${agentmemoryVersion}.tgz";
          hash = "sha256-QU7FKhikaKDdetNtGm3osAv7NeHO+q5DfrdKveAmc18=";
        };
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
          runHook preInstall
          mkdir -p "$out/node_modules"
          cp -r . "$out/"
          ln -s ${picocolors} "$out/node_modules/picocolors"
          runHook postInstall
        '';
      };

      # The stdio bridge, pinned instead of fetched. This used to be
      # `npx -y @agentmemory/mcp`, which pulled unpinned code off the network on
      # every agent launch and ran it with the bearer token already in its
      # environment — and made agent startup depend on npm being reachable.
      #
      # No buildNpmPackage is needed. The package is a single bin.mjs whose only
      # dependency is @agentmemory/agentmemory (already pinned above), which it
      # reaches by bare specifier — so it just needs to resolve through a
      # node_modules dir. That package's other dependencies don't matter here:
      # dist/standalone.mjs is bundled and imports only node: builtins plus
      # picocolors, which agentmemoryPkg carries. Its package.json `exports` whitelists the ./dist/standalone.mjs subpath,
      # so the import resolves cleanly.
      agentmemoryMcp = pkgs.stdenvNoCC.mkDerivation {
        pname = "agentmemory-mcp";
        version = agentmemoryVersion;
        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/@agentmemory/mcp/-/mcp-${agentmemoryVersion}.tgz";
          hash = "sha256-+AFoMnPHx+bzQgaOzxjR1k+dVmvRvqpEGmRwRcMoLis=";
        };
        sourceRoot = "package";
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
          runHook preInstall
          install -Dm644 bin.mjs "$out/libexec/agentmemory-mcp/bin.mjs"
          install -Dm644 package.json "$out/libexec/agentmemory-mcp/package.json"
          mkdir -p "$out/libexec/agentmemory-mcp/node_modules/@agentmemory"
          ln -s ${agentmemoryPkg} "$out/libexec/agentmemory-mcp/node_modules/@agentmemory/agentmemory"
          runHook postInstall
        '';
      };

      # One wrapper for every lifecycle hook. It reads the bearer token from the
      # sops secret at run time so the token never lands in any agent config, points
      # at the memory engine, and asks for context injection only on the two
      # cheap, high-value events (session start and pre-compact). PreToolUse is
      # deliberately not wired: that script is injection-only — a no-op without
      # injection — and PostToolUse already records tool activity.
      agentmemoryHook = pkgs.writeShellScriptBin "agentmemory-hook" ''
        set -euo pipefail
        hook="''${1:?usage: agentmemory-hook <hook-name>}"
        export PATH="${pkgs.git}/bin:${pkgs.nodejs}/bin:''${PATH:-/usr/bin:/bin}"
        export AGENTMEMORY_URL="${agentmemoryURL}"
        export AGENTMEMORY_TOOLS="all"
        case "$hook" in
          session-start|pre-compact) export AGENTMEMORY_INJECT_CONTEXT="true" ;;
        esac
        if [ -r "${agentmemoryTokenFile}" ]; then
          AGENTMEMORY_SECRET="$(cat "${agentmemoryTokenFile}")"
          export AGENTMEMORY_SECRET
        else
          echo "agentmemory-hook: ${agentmemoryTokenFile} not readable; running unauthenticated" >&2
        fi
        exec ${pkgs.nodejs}/bin/node "${agentmemoryPlugin}/plugin/scripts/$hook.mjs"
      '';

      hookCmd = script: "${agentmemoryHook}/bin/agentmemory-hook ${script}";
      mkHook = script: [
        {
          hooks = [
            {
              type = "command";
              command = hookCmd script;
            }
          ];
        }
      ];

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
        [ -r "${agentmemoryTokenFile}" ] || exit 0
        tok="$(cat "${agentmemoryTokenFile}")"; [ -n "$tok" ] || exit 0
        u="${agentmemoryURL}/agentmemory"
        ids="$(curl -s --max-time 2 -X POST -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' \
          -d '{"matchAll":["inject:session-start"],"targetType":"memory"}' "$u/facets/query" \
          | jq -r '.results[]?.targetId' 2>/dev/null)" || exit 0
        [ -n "$ids" ] || exit 0
        ctx="$(for id in $ids; do curl -s --max-time 2 -H "Authorization: Bearer $tok" "$u/memories/$id"; done \
          | jq -rs 'sort_by(.memory.title) | map(.memory.content) | join("\n\n")' 2>/dev/null)" || exit 0
        [ -n "$ctx" ] && printf '# Standing directives (recalled from agentmemory)\n\n%s\n' "$ctx"
        exit 0
      '';
      injectEntry = [
        {
          hooks = [
            {
              type = "command";
              command = "${directiveInject}";
            }
          ];
        }
      ];

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

      # Copilot CLI. Flat native entries under the PascalCase names, which deliver
      # the same snake_case payloads Claude Code sends; subagentStart and
      # notification exist only in camelCase, and the scripts read both
      # spellings. Copilot injects SessionStart output only as JSON
      # additionalContext, so both context producers are wrapped. PreCompact is
      # left out: Copilot discards its output, and the script does nothing else
      # (the Claude bridge sync it can run is off).
      copilotContext = pkgs.writeShellScript "copilot-additional-context" ''
        out="$("$@")" || exit 0
        [ -n "$out" ] || exit 0
        ${pkgs.jq}/bin/jq -n --arg c "$out" '{additionalContext: $c}'
      '';
      copilotEntry = command: [
        {
          type = "command";
          bash = command;
        }
      ];
      copilotHook = script: copilotEntry (hookCmd script);
      copilotHooks = {
        SessionStart =
          copilotEntry "${copilotContext} ${hookCmd "session-start"}"
          ++ copilotEntry "${copilotContext} ${directiveInject}";
        UserPromptSubmit = copilotHook "prompt-submit";
        PostToolUse = copilotHook "post-tool-use";
        PostToolUseFailure = copilotHook "post-tool-failure";
        subagentStart = copilotHook "subagent-start";
        SubagentStop = copilotHook "subagent-stop";
        notification = copilotHook "notification";
        Stop = copilotHook "stop";
        SessionEnd = copilotHook "session-end";
      };

      agentmemorySkills = [
        "remember"
        "recall"
        "recap"
        "handoff"
        "forget"
        "commit-context"
        "commit-history"
        "session-history"
      ];
      mkSkillLinks =
        dir:
        lib.listToAttrs (
          map (s: {
            name = "${dir}/${s}";
            value.source = "${agentmemoryPlugin}/plugin/skills/${s}";
          }) agentmemorySkills
        );
    in
    {
      # Claude Code lifecycle hooks, contributed declaratively to the list-merging
      # programs.claudeCode.hooks option that home/claude/claude.nix folds into
      # ~/.claude/settings.json (per-event lists concatenate across modules, so
      # home/claude/session-directives.nix can also append a SessionStart hook).
      # (Codex, whose config is TOML, still gets its hooks via the activation merge
      # below.)
      programs.claudeCode.hooks = claudeHooks;

      # Codex lifecycle hooks, contributed to the twin list-merging option that
      # home/codex/codex.nix folds into ~/.codex/hooks.json. Declarative like
      # Claude's since codex.nix grew that option — the runtime jq merge this
      # replaces appended a fresh copy of the directive-injection entry on every
      # activation, because its drop-predicate only matched "agentmemory-hook".
      # The wrapper reads the bearer token at run time, so these are wired
      # regardless of token state and carry no secret in the file.
      programs.codexCli.hooks = codexHooks;

      # Copilot CLI lifecycle hooks, contributed to the list-merging option
      # home/copilot/copilot.nix renders into ~/.copilot/hooks/home-manager.json.
      programs.copilotCli.hooks = copilotHooks;

      # Registered with every agent by home/agent-mcp.nix. No bearer token
      # lands in any client config: each client launches the wrapper, which
      # reads the token from the sops file at spawn time. dsh has no
      # lifecycle-hook seam, so it gets no auto-capture counterpart and
      # ~/.dsh/AGENTS.md §11 says so outright.
      agentMcpServers.agentmemory.command = mcpBin;

      # agentmemory skills for Claude Code, Codex, dsh, and Copilot: read-only symlinks
      # into the pinned plugin. The slash commands (/remember, /recall, ...) come
      # from each skill's SKILL.md frontmatter name, not the directory name. dsh
      # scans $DSH_HOME/skills through its filesystem skill provider, so the same
      # per-skill links land there, as does Copilot's personal ~/.copilot/skills;
      # keying them individually leaves the parent directory writable for
      # hand-placed skills.
      home.file =
        (mkSkillLinks ".claude/skills")
        // (mkSkillLinks ".codex/skills")
        // (mkSkillLinks ".dsh/skills")
        // (mkSkillLinks ".copilot/skills");
    };
}
