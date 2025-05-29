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
    plex-desktop
    signal-desktop
    spotify
  ];
}
