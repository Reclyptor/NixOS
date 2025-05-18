{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    aseprite
    brave
    discord
    imv
    krita
    makemkv
    mpv
    plex-desktop
    spotify
  ];
}
