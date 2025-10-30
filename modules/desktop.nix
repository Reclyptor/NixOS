{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    bibata-cursors
    cliphist
    gnome-themes-extra
    gsettings-desktop-schemas
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
