_: {
  flake.modules.homeManager.base =
    { pkgs, ... }:
    let
      aliasName = "wayland-current";

      # WAYLAND_DISPLAY is authoritative here rather than guessed, because of how
      # the compositor hands its environment to systemd. The generated
      # ~/.config/hypr/hyprland.conf — from wayland.windowManager.hyprland's
      # systemd.enable in hyprland.nix — opens with:
      #
      #   exec-once = dbus-update-activation-environment --systemd DISPLAY \
      #       HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP \
      #       XDG_SESSION_TYPE && systemctl --user stop hyprland-session.target \
      #       && systemctl --user start hyprland-session.target
      #
      # The import finishes before the target starts, and the target is stopped
      # and restarted on every Hyprland start. So a unit wanted by that target
      # always runs with the live value, and scanning XDG_RUNTIME_DIR for
      # wayland-* sockets would only be a worse way to learn what we were handed.
      #
      # libwayland accepts either a bare name resolved under XDG_RUNTIME_DIR or an
      # absolute path, so both spellings are normalized to a path before linking.
      link = pkgs.writeShellScript "wayland-socket-alias-link" ''
        set -euo pipefail

        runtime="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is unset}"
        socket="''${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is unset}"

        case "$socket" in
          /*) ;;
          *) socket="$runtime/$socket" ;;
        esac

        if [ ! -S "$socket" ]; then
          echo "wayland-socket-alias: no compositor socket at $socket" >&2
          exit 1
        fi

        ln -sfn "$socket" "$runtime/${aliasName}"
      '';

      unlink = pkgs.writeShellScript "wayland-socket-alias-unlink" ''
        set -euo pipefail
        rm -f "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is unset}/${aliasName}"
      '';
    in
    {
      # A fixed name for whichever socket the current compositor is on, so a user
      # service that deliberately outlives the compositor can still reach it.
      #
      # herdr is the consumer (see home/herdr/herdr.nix): its server is kept out
      # of graphical-session.target so a Hyprland restart cannot take the agent
      # panes with it, which also means it cannot hold a wayland-N name — Hyprland
      # takes the first free number, and a running process's environment cannot be
      # rewritten afterwards. Pointing it at this alias inverts the problem: the
      # value herdr carries never changes, and what it resolves to is re-aimed
      # here on every compositor start.
      #
      # This lives with the compositor rather than with herdr because the
      # compositor's lifecycle is what produces it. Nothing orders herdr against
      # this unit, and nothing needs to: the symlink is dereferenced by a client
      # inside a pane at connect() time, not by herdr at start.
      systemd.user.services.wayland-socket-alias = {
        Unit = {
          Description = "Stable ${aliasName} alias for the live Wayland socket";
          PartOf = [ "hyprland-session.target" ];
        };

        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = toString link;
          ExecStop = toString unlink;
        };

        Install.WantedBy = [ "hyprland-session.target" ];
      };
    };
}
