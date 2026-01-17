{ pkgs, ... }: {
  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    cliphist
    glib # for gsettings
    gsettings-desktop-schemas
    libnotify
    mako
    nautilus
    qt6.qtbase
    wl-clipboard
    xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland
    xdg-utils
  ];

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };
}
