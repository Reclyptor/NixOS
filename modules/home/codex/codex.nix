_: {
  flake.modules.homeManager.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Per-event Codex hook lists, merged across modules and serialized to
      # ~/.codex/hooks.json. The twin of programs.claudeCode.hooks in
      # home/claude/claude.nix, and for the same reason: attrsOf (listOf ...)
      # CONCATENATES, so agentmemory's lifecycle hooks and herdr's session-identity
      # hook can each contribute to SessionStart without knowing about each other.
      #
      # This replaces a runtime jq merge that appended on every activation and
      # matched its own prior entries by script name. The name it matched missed
      # the directive-injection wrapper, so that entry accumulated — 64 copies of
      # it by the time Codex hooks were switched on. Composition in the module
      # system cannot drift that way: the file is generated whole, every time.
      options.programs.codexCli.hooks = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.anything);
        default = { };
        description = "Per-event Codex hook lists, merged across modules and serialized to ~/.codex/hooks.json.";
      };

      config = {
        # Global Codex directives, installed read-only as ~/.codex/AGENTS.md so they load
        # as the user-level config for every session. Edit ./AGENTS.md next to this module.
        home.file.".codex/AGENTS.md".source = ./AGENTS.md;

        home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              CODEX_CFG="$HOME/.codex/config.toml"

              $DRY_RUN_CMD mkdir -p "$HOME/.codex"

              PRESERVED=""
              if [ -f "$CODEX_CFG" ]; then
                PRESERVED=$(${pkgs.gawk}/bin/awk '
                  /^\[projects\./ { p = 1; print; next }
                  /^\[/           { p = 0; next }
                  p               { print }
                ' "$CODEX_CFG")
              fi

              {
                cat <<'BASE_EOF'
          # Managed declaratively by home/codex/codex.nix.
          # Edits to top-level keys and [features] will be overwritten on the next
          # home-manager activation. [projects.*] sections (trust levels) are preserved
          # from codex's own writes across rebuilds. The agentmemory MCP server block is
          # appended by home/agentmemory.nix.

          model = "gpt-5.5"
          model_reasoning_effort = "high"

          [features]
          goals = true
          # agentmemory (MCP) is the exclusive memory path — native memories off.
          memories = false
          # Required by herdr's codex integration (home/herdr/herdr.nix), which
          # reports session identity through a SessionStart hook. It also switches
          # on agentmemory's codex lifecycle hooks, which have been sitting in
          # ~/.codex/hooks.json without this flag to dispatch them.
          hooks = true
          BASE_EOF
                if [ -n "$PRESERVED" ]; then
                  printf '\n%s\n' "$PRESERVED"
                fi
              } > "$CODEX_CFG.tmp"

              $DRY_RUN_CMD mv "$CODEX_CFG.tmp" "$CODEX_CFG"
              $DRY_RUN_CMD chmod 600 "$CODEX_CFG"
        '';

        # Serialize the merged hook lists to ~/.codex/hooks.json as a read-only
        # store file, the same contract as ~/.claude/settings.json. Codex only ever
        # reads this file — nothing in the binary writes it, and hook trust is
        # persisted elsewhere — so nothing is fighting us for ownership. If that
        # ever changes, the symptom is a failed write from codex, and the fallback
        # is a runtime merge with a predicate matching every agentmemory script.
        home.file.".codex/hooks.json" = lib.mkIf (config.programs.codexCli.hooks != { }) {
          source = (pkgs.formats.json { }).generate "codex-hooks.json" {
            hooks = config.programs.codexCli.hooks;
          };
        };
      };
    };
}
