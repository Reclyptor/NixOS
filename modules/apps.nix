{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    aseprite
    audacity
    brave
    google-chrome
    discord
    firefox
    imv
    inkscape
    krita
    makemkv
    mkvtoolnix
    mpv
    obs-studio
    obsidian
    qbittorrent
    signal-desktop
    spotify
  ];
}
