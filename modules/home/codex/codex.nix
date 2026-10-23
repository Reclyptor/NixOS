_: {
  # Codex runs a hook from the user layer (~/.codex/hooks.json) only after the
  # user trusts it, and trust is pinned to a hash of the hook's normalized
  # definition, command string included. Every hook here invokes a Nix store
  # path, so any rebuild that touches a hook script changes its hash, and Codex
  # silently stops running it until someone notices and re-trusts. That is how
  # the mascot went dark for Codex after a routine rebuild.
  #
  # Hooks in the System layer (/etc/codex, beside /etc/codex/config.toml) are
  # managed: Codex reports them as HookTrustStatus::Managed and runs them
  # without a trust record, because whoever can write /etc already decided.
  # Here that decision is this repository, so the merged hooks are rendered
  # there. Source: codex-rs/hooks/src/engine/discovery.rs at rust-v0.160.0,
  # hook_metadata_for_config_layer_source and the per-layer hooks.json load.
  #
  # The system layer is machine-wide, so every Home Manager user's hooks are
  # concatenated into it. This host has one.
  flake.modules.nixos.workstation =
    { config, lib, ... }:
    let
      users = lib.attrValues (lib.attrByPath [ "home-manager" "users" ] { } config);
      hooks = lib.zipAttrsWith (_: lib.concatLists) (map (u: u.programs.codexCli.hooks) users);
    in
    {
      environment.etc."codex/hooks.json" = lib.mkIf (hooks != { }) {
        text = builtins.toJSON { inherit hooks; };
      };
    };

  flake.modules.homeManager.base =
    {
      lib,
      pkgs,
      ...
    }:
    {
      # Per-event Codex hook lists, merged across modules and rendered by the
      # NixOS module above into /etc/codex/hooks.json. The twin of
      # programs.claudeCode.hooks in home/claude/claude.nix, and for the same
      # reason: attrsOf (listOf ...) CONCATENATES, so agentmemory's lifecycle
      # hooks and herdr's session-identity hook can each contribute to
      # SessionStart without knowing about each other.
      #
      # This replaces a runtime jq merge that appended on every activation and
      # matched its own prior entries by script name. The name it matched missed
      # the directive-injection wrapper, so that entry accumulated — 64 copies of
      # it by the time Codex hooks were switched on. Composition in the module
      # system cannot drift that way: the file is generated whole, every time.
      options.programs.codexCli.hooks = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.anything);
        default = { };
        description = "Per-event Codex hook lists, merged across modules and rendered to the managed /etc/codex/hooks.json.";
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
          # from codex's own writes across rebuilds. The [mcp_servers.*] blocks are
          # appended by home/agent-mcp.nix.

          model = "gpt-5.6-terra"
          model_reasoning_effort = "high"

          [features]
          goals = true
          # agentmemory (MCP) is the exclusive memory path — native memories off.
          memories = false
          # Required by herdr's codex integration (home/herdr/herdr.nix), which
          # reports session identity through a SessionStart hook, and by every
          # other hook in the managed /etc/codex/hooks.json.
          hooks = true
          BASE_EOF
                if [ -n "$PRESERVED" ]; then
                  printf '\n%s\n' "$PRESERVED"
                fi
              } > "$CODEX_CFG.tmp"

              # Skip the rename when the regenerated config is byte-identical:
              # codex rewrites this file itself (trust levels, mcp blocks), and
              # a no-op switch should not churn it under a running session.
              if cmp -s "$CODEX_CFG.tmp" "$CODEX_CFG"; then
                rm -f "$CODEX_CFG.tmp"
              else
                $DRY_RUN_CMD mv "$CODEX_CFG.tmp" "$CODEX_CFG"
                $DRY_RUN_CMD chmod 600 "$CODEX_CFG"
              fi
        '';
      };
    };
}
