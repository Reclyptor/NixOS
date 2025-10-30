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
    xz
    yq
    yt-dlp
    zip
  ];
}
