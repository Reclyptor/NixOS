_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    programs.dconf.enable = true;

    environment.systemPackages = with pkgs; [
      cliphist
      glib # for gsettings
      libnotify
      mako
      kdePackages.dolphin
      qt6.qtbase
      wl-clipboard
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
      xdg-utils
    ];

    # Qt is themed through its GTK3 platform theme (modules/home/theme.nix), so
    # every QFileDialog is really a GtkFileChooser, and that reads the
    # org.gtk.Settings.FileChooser schema; a missing schema is a hard abort in
    # GLib, not an error. Nix installs schemas under
    # share/gsettings-schemas/<name>/, which GLib never searches, so only apps
    # built with wrapGAppsHook could find them — any other Qt app crashed the
    # moment it opened a file dialog. Putting them on the session's
    # XDG_DATA_DIRS fixes every app at once. Listing gsettings-desktop-schemas in
    # systemPackages, as this used to, made nothing findable.
    environment.sessionVariables.XDG_DATA_DIRS = map pkgs.glib.getSchemaDataDirPath [
      pkgs.gtk3
      pkgs.gsettings-desktop-schemas
    ];

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config = {
        common.default = [ "gtk" ];
        hyprland.default = [
          "gtk"
          "hyprland"
        ];
      };
    };
  };
}
