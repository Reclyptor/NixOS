{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    bibata-cursors
    gnome-themes-extra
    gsettings-desktop-schemas
    nautilus
    qt6.qtbase
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
