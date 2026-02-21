{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    btop
    eza
    fastfetch
    ffmpeg-full
    fluxcd
    git
    htop
    iotop
    jq
    killall
    kubectl
    kubernetes-helm
    libnatpmp
    lsof
    ncdu
    neovim
    nmap
    oh-my-posh
    p7zip
    pciutils
    rar
    talosctl
    unrar
    unzip
    usbutils
    wget
    xclip
    xxd
    xz
    yq
    yt-dlp
    zip
  ];
}
