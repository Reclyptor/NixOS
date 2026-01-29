{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    aseprite
    audacity
    brave
    code-cursor
    google-chrome
    hytale
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
    vlc
    vintagestory
    whipper
    yubikey-manager
    yubico-piv-tool
  ];
}
