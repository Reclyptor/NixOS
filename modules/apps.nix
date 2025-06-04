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
    signal-desktop
    spotify
  ];
}
