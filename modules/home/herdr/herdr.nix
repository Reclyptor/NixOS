{ inputs, ... }:
{
  flake.modules.homeManager.base =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      home = config.home.homeDirectory;
      inherit (config) palette;

      # herdr's own integration assets, read out of the pinned input rather than
      # vendored, so the scripts can never drift from the binary whose socket
      # protocol they speak. Both are POSIX sh + python3 and exit 0 immediately
      # unless HERDR_ENV=1 — outside a herdr pane they do nothing.
      claudeHookSrc = "${inputs.herdr}/src/integration/assets/claude/herdr-agent-state.sh";
      codexHookSrc = "${inputs.herdr}/src/integration/assets/codex/herdr-agent-state.sh";

      # Installed at the paths herdr's own installer uses, so `herdr integration
      # status` recognizes them and stays a truthful drift canary. The installer
      # itself cannot run here: it resolves ~/.claude/settings.json through its
      # symlink and refuses a target under /nix/store (check_config_targets in
      # src/integration/config_file.rs), aborting before it writes either script.
      claudeHook = "${home}/.claude/hooks/herdr-agent-state.sh";
      codexHook = "${home}/.codex/herdr-agent-state.sh";

      # Mirrors src/integration/command.rs: `bash '<path>' session`, single-quoted.
      hookCommand = path: "bash '${path}' session";

      # Both agents get one SessionStart hook with a 10s timeout — that whole
      # integration is session identity, nothing more; state itself comes from
      # herdr's screen detection. Claude filters the event sources it fires on
      # (src/integration/claude_settings.rs); codex passes no matcher.
      hookTimeout = 10;
      claudeMatcher = "^(startup|resume|clear|compact|fork)$";

      codexHooksJson = builtins.toJSON {
        SessionStart = [
          {
            hooks = [
              {
                type = "command";
                command = hookCommand codexHook;
                timeout = hookTimeout;
              }
            ];
          }
        ];
      };

      # Same non-destructive shape home/agentmemory.nix uses for the same file:
      # drop any prior herdr entry (matched by the script name, so a stale store
      # path from an earlier pin is replaced rather than duplicated), append the
      # current one, leave every foreign hook — agentmemory's included — intact.
      hookMergeProg = ''
        .hooks = (.hooks // {})
        | reduce ($herdr | to_entries[]) as $e (.;
            .hooks[$e.key] = (
              (((.hooks[$e.key]) // [])
                | map(select(([ .hooks[]? | .command // "" ] | any(test("herdr-agent-state"))) | not)))
              + $e.value
            )
          )
      '';

      # Seed only — herdr writes this file itself (onboarding, the in-app settings
      # menu, `herdr server reload-config`), so a read-only store symlink would
      # break all three. Every key here is one herdr prints in --default-config.
      # The "terminal" base theme takes its colors from kitty, which home/kitty.nix
      # already themes from this same palette; the overrides below pin the surfaces
      # herdr draws itself.
      configSeed = pkgs.writeText "herdr-config.toml" ''
        # Seeded once by home/herdr/herdr.nix. Not managed after that — edit it
        # here or in herdr's settings menu, whichever you prefer.

        onboarding = false

        [theme]
        name = "terminal"

        [theme.custom]
        sidebar_bg = "#${palette.backgroundDark}"
        panel_bg = "#${palette.background}"
        active_row_bg = "#${palette.surface}"
        selection_bg = "#${palette.surfaceLight}"
        accent = "#${palette.accent}"
        red = "#${palette.urgent}"

        [update]
        # The binary comes from the flake, so herdr cannot update itself: its
        # store path is read-only and a new version belongs in flake.lock.
        # Detection manifests are data, not code, and keep updating.
        version_check = false

        [session]
        # Resume agent panes into their native conversations after a server
        # restart. This is what the Claude/Codex SessionStart hooks above feed.
        resume_agents_on_restore = true
      '';
    in
    {
      home.packages = [ pkgs.herdr ];

      # The hook scripts themselves. Read-only store symlinks: herdr only writes
      # here during `integration install`, which we never run.
      home.file.".claude/hooks/herdr-agent-state.sh".source = claudeHookSrc;
      home.file.".codex/herdr-agent-state.sh".source = codexHookSrc;

      # Claude Code: contributed to the list-merging option home/claude/claude.nix
      # folds into ~/.claude/settings.json, so this concatenates with
      # agentmemory's SessionStart hooks instead of conflicting with them.
      programs.claudeCode.hooks.SessionStart = [
        {
          matcher = claudeMatcher;
          hooks = [
            {
              type = "command";
              command = hookCommand claudeHook;
              timeout = hookTimeout;
            }
          ];
        }
      ];

      # Codex: TOML client with no declarative home-manager surface, so its hook
      # is a runtime jq-merge like agentmemory's. Ordered after both writers of
      # the files it touches; the merge is idempotent, so the order only keeps
      # the diff quiet. `[features] hooks = true` lives in home/codex/codex.nix,
      # whose activation rewrites config.toml on every switch.
      home.activation.herdrCodexHook =
        lib.hm.dag.entryAfter
          [
            "writeBoundary"
            "codexConfig"
            "agentmemory"
          ]
          ''
            herdr_hooks="$HOME/.codex/hooks.json"
            $DRY_RUN_CMD mkdir -p "$(dirname "$herdr_hooks")"
            if [ -f "$herdr_hooks" ]; then base="$(cat "$herdr_hooks")"; else base="{}"; fi
            if printf '%s' "$base" \
              | ${pkgs.jq}/bin/jq --argjson herdr ${lib.escapeShellArg codexHooksJson} \
                  '${hookMergeProg}' > "$herdr_hooks.herdr.tmp"; then
              $DRY_RUN_CMD mv -- "$herdr_hooks.herdr.tmp" "$herdr_hooks"
            else
              rm -f "$herdr_hooks.herdr.tmp"
              echo "herdr: jq hook merge failed for $herdr_hooks (left unchanged)" >&2
            fi
          '';

      # Written once, then left alone — see configSeed above.
      home.activation.herdrConfigSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        herdr_config="$HOME/.config/herdr/config.toml"
        if [ ! -f "$herdr_config" ]; then
          $DRY_RUN_CMD mkdir -p "$(dirname "$herdr_config")"
          $DRY_RUN_CMD install -m 644 ${configSeed} "$herdr_config"
        fi
      '';

      # The server owns the agent terminals, so it must outlive any one client.
      # Deliberately not PartOf graphical-session: a Hyprland restart takes the
      # kitty windows with it and must leave the herd running.
      systemd.user.services.herdr = {
        Unit = {
          Description = "herdr — the runtime the coding agents live on";
          Documentation = "https://herdr.dev/docs/";
          After = [ "default.target" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${pkgs.herdr}/bin/herdr server";
          ExecStop = "${pkgs.herdr}/bin/herdr server stop";
          Restart = "on-failure";
          RestartSec = 2;
        };

        Install.WantedBy = [ "default.target" ];
      };
    };
}
