{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    aseprite
    audacity
    brave
    discord
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
