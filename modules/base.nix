{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    age
    age-plugin-yubikey
    eza
    fastfetch
    ffmpeg-full
    fluxcd
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
    sops
    talosctl
    unzip
    wget
    xclip
    yt-dlp
    zip
  ];
}
