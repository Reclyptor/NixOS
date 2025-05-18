{ config, pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    aseprite
    bibata-cursors
    brave
    discord
    docker
    eza
    fastfetch
    git
    gnome-themes-extra
    gnupg
    gsettings-desktop-schemas
    hyprcursor
    hypridle
    hyprland
    hyprlock
    hyprpaper
    hyprpicker
    hyprsunset
    imv
    kitty
    kitty-themes
    krita
    makemkv
    mongosh
    mpv
    mysql84
    nautilus
    neovim
    oh-my-posh
    playerctl
    plex-desktop
    qt6.qtbase
    spotify
    steam
    waybar
    wget
    wofi
    xdg-desktop-portal-hyprland
    xdg-utils
  ];
}
