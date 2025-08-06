{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    aseprite
    audacity
    brave
    discord
    firefox
    imv
    inkscape
    krita
    makemkv
    mpv
    obs-studio
    obsidian
    qbittorrent
    signal-desktop
    spotify
  ];
}
