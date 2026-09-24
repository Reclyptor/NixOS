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

        [keys]
        # tmux's keymap, so one set of reflexes covers both multiplexers. Herdr
        # tabs are tmux windows and herdr workspaces are tmux sessions. Where
        # tmux binds a key to something herdr has no action for — t, i, q, f —
        # that key goes to a herdr feature rather than being held vacant.
        prefix = "ctrl+b"

        # Session and client. tmux spends t on clock-mode and leaves Tab
        # unbound, which is where settings and the notification jump land.
        detach = "prefix+d"
        help = "prefix+?"
        settings = "prefix+t"
        open_notification_target = "prefix+tab"
        reload_config = "prefix+shift+r"
        toggle_sidebar = "prefix+b"

        # Workspaces — tmux sessions. goto is herdr's session navigator, so it
        # takes choose-tree -Zs; workspace_picker keeps w for choose-tree -Zw.
        goto = "prefix+s"
        workspace_picker = "prefix+w"
        rename_workspace = "prefix+$"
        previous_workspace = "prefix+("
        next_workspace = "prefix+)"
        new_workspace = "prefix+shift+n"
        close_workspace = "prefix+shift+d"
        new_worktree = "prefix+shift+g"

        # Tabs — tmux windows. switch_tab stops at 9: indexed bindings are
        # validated as 1..9 in src/config/keybinds.rs, and herdr tabs are
        # 1-indexed, so tmux's select-window 0 has nothing to select here.
        new_tab = "prefix+c"
        rename_tab = "prefix+comma"
        close_tab = "prefix+ampersand"
        previous_tab = "prefix+p"
        next_tab = "prefix+n"
        switch_tab = "prefix+1..9"
        move_tab_previous = "prefix+shift+left"
        move_tab_next = "prefix+shift+right"

        # Panes. The split names read inverted against tmux because tmux names
        # the divider and herdr names the axis: split_vertical opens to the
        # right (tmux's %), split_horizontal opens below (tmux's ").
        split_vertical = "prefix+percent"
        split_horizontal = "prefix+double_quote"
        close_pane = "prefix+x"
        zoom = "prefix+z"
        copy_mode = "prefix+["
        rename_pane = "prefix+shift+p"
        edit_scrollback = "prefix+e"

        # Focus on the arrows, as tmux ships it. Plain prefix+hjkl is left free
        # on purpose; navigate mode keeps its own hjkl, a separate binding set
        # that this does not touch.
        focus_pane_left = "prefix+left"
        focus_pane_down = "prefix+down"
        focus_pane_up = "prefix+up"
        focus_pane_right = "prefix+right"

        # tmux has no reverse cycle, so shift+o mirrors o the way shift mirrors
        # its counterpart everywhere else here.
        cycle_pane_next = "prefix+o"
        cycle_pane_previous = "prefix+shift+o"
        last_pane = "prefix+;"

        # tmux panes are a linear list, so swap-pane only knows -U and -D. The
        # < and > keys carry the horizontal axis herdr has and tmux does not.
        swap_pane_up = "prefix+{"
        swap_pane_down = "prefix+}"
        swap_pane_left = "prefix+<"
        swap_pane_right = "prefix+>"

        # Mirrors `bind -r H resize-pane -L 5` in home/tmux.nix. Herdr has no
        # repeat equivalent, so each press nudges 5% and resize_mode is the real
        # stand-in for tmux's -r: prefix+r once, then hjkl as long as you like.
        resize_pane_left = "prefix+shift+h"
        resize_pane_down = "prefix+shift+j"
        resize_pane_up = "prefix+shift+k"
        resize_pane_right = "prefix+shift+l"
        resize_mode = "prefix+r"
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

      # Codex: the twin contribution, through the list-merging option
      # home/codex/codex.nix folds into ~/.codex/hooks.json. Same single entry as
      # Claude's above, minus the matcher — upstream passes none for codex
      # (src/integration/targets.rs). `[features] hooks = true`, which codex needs
      # to dispatch any of this, lives in that module too.
      programs.codexCli.hooks.SessionStart = [
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
