{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    audacity
    brave
    code-cursor
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
    whipper
    yubikey-manager
    yubico-piv-tool
  ];
}
