{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    aseprite
    audacity
    brave
    discord
    imv
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
