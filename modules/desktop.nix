{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    bibata-cursors
    gnome-themes-extra
    gsettings-desktop-schemas
    nautilus
    qt6.qtbase
    xdg-desktop-portal-hyprland
    xdg-utils
    playerctl
    pavucontrol
    networkmanager
    networkmanagerapplet
  ];
}
