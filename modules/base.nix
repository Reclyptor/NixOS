{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    eza
    fastfetch
    ffmpeg-full
    git
    gnupg
    jq
    kubectl
    kubernetes-helm
    libnatpmp
    neovim
    nmap
    oh-my-posh
    openssl
    talosctl
    unzip
    wget
    xclip
    yt-dlp
    zip
  ];
}
