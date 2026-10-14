_: {
  flake.modules.homeManager.base =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      servers = config.agentMcpServers;

      # Each agent keeps its MCP servers under its own key and in its own entry
      # shape. A program merges every declared server into that key and leaves
      # the rest of the file, including servers added by hand, alone. The
      # entries are JSON literals baked in by Nix, so the merge needs no --arg.
      mergeProg = prefix: key: entry: ''
        ${prefix}.${key} += ${builtins.toJSON (lib.mapAttrs (_: entry) servers)}
      '';
      stdio = s: { inherit (s) command args; };

      claudeProg = mergeProg "" "mcpServers" stdio;
      crushProg = mergeProg ''.["$schema"] = "https://charm.land/crush.json" | '' "mcp" (
        s: { type = "stdio"; } // stdio s
      );
      opencodeProg = mergeProg ''.["$schema"] = "https://opencode.ai/config.json" | '' "mcp" (s: {
        type = "local";
        command = [ s.command ] ++ s.args;
        enabled = true;
      });
      # Prime Agent's entries are internally tagged by `type`.
      primeAgentProg = mergeProg "" "mcpServers" (s: { type = "stdio"; } // stdio s);
      # Copilot CLI exposes only the tools an entry allowlists; "*" is all of them.
      copilotProg = mergeProg "" "mcpServers" (
        s:
        {
          type = "local";
          tools = [ "*" ];
        }
        // stdio s
      );

      # TOML basic strings share JSON's escapes, so toJSON renders valid TOML
      # for both strings and string arrays.
      codexBlocks = lib.concatStrings (
        lib.mapAttrsToList (name: s: ''

          [mcp_servers.${name}]
          command = ${builtins.toJSON s.command}
          ${lib.optionalString (s.args != [ ]) "args = ${builtins.toJSON s.args}\n"}'') servers
      );
    in
    {
      options.agentMcpServers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              command = lib.mkOption {
                type = lib.types.str;
                description = ''
                  Executable each agent spawns for the server's stdio
                  transport. It lands in every agent's config file, so it must
                  carry no secret: a server that needs a credential reads it
                  itself at spawn time.
                '';
              };

              args = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Arguments passed to `command`.";
              };
            };
          }
        );
        default = { };
        description = ''
          MCP servers registered with every agent: Claude Code, Qwen Code,
          Crush, opencode, Prime Agent, Copilot CLI, Codex and dsh. Keyed by
          the server name the agents namespace its tools under.
        '';
      };

      config = lib.mkIf (servers != { }) {
        # dsh renders these into every profile's patch itself.
        deepseek.mcpServers = lib.mapAttrs (_: stdio) servers;

        # JSON agents are jq-merged in place. Codex's blocks are appended onto
        # the config.toml that codexConfig just regenerated, which keeps only
        # [projects.*], so every run starts without them and the append is
        # deterministic. Self-heals on every switch.
        home.activation.agentMcp = lib.hm.dag.entryAfter [ "writeBoundary" "codexConfig" ] ''
          mcp_merge() {
            local file="$1" prog="$2" base
            $DRY_RUN_CMD mkdir -p "$(dirname "$file")"
            if [ -f "$file" ]; then base="$(cat "$file")"; else base="{}"; fi
            if printf '%s' "$base" | ${lib.getExe pkgs.jq} "$prog" > "$file.mcp.tmp"; then
              $DRY_RUN_CMD mv -- "$file.mcp.tmp" "$file"
            else
              rm -f "$file.mcp.tmp"
              echo "agent-mcp: jq merge failed for $file (left unchanged)" >&2
            fi
          }

          mcp_merge "$HOME/.claude.json"                   ${lib.escapeShellArg claudeProg}
          mcp_merge "$HOME/.qwen/settings.json"            ${lib.escapeShellArg claudeProg}
          mcp_merge "$HOME/.config/crush/crush.json"       ${lib.escapeShellArg crushProg}
          mcp_merge "$HOME/.config/opencode/opencode.json" ${lib.escapeShellArg opencodeProg}
          mcp_merge "$HOME/.prime/agent/settings.json"     ${lib.escapeShellArg primeAgentProg}
          mcp_merge "$HOME/.copilot/mcp-config.json"       ${lib.escapeShellArg copilotProg}

          codex_toml="$HOME/.codex/config.toml"
          if [ ! -f "$codex_toml" ]; then
            echo "agent-mcp: $codex_toml missing (codexConfig should create it), skipping codex" >&2
          elif ${pkgs.gnugrep}/bin/grep -q '^\[mcp_servers\.' "$codex_toml"; then
            echo "agent-mcp: $codex_toml already has [mcp_servers.*] blocks codexConfig should have stripped, skipping codex" >&2
          else
            printf '%s' ${lib.escapeShellArg codexBlocks} | cat "$codex_toml" - > "$codex_toml.mcp.tmp"
            $DRY_RUN_CMD mv -- "$codex_toml.mcp.tmp" "$codex_toml"
            $DRY_RUN_CMD chmod 600 "$codex_toml"
          fi
        '';
      };
    };
}
