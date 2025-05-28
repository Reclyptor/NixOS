{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    aseprite
    brave
    discord
    imv
    krita
    makemkv
    mpv
    obsidian
    plex-desktop
    signal-desktop
    spotify
  ];
}
