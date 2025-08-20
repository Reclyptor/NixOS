{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    eza
    fastfetch
    ffmpeg-full
    fluxcd
    git
    jq
    kubectl
    kubernetes-helm
    libnatpmp
    neovim
    nmap
    oh-my-posh
    talosctl
    unzip
    wget
    xclip
    yq
    yt-dlp
    zip
  ];
}
