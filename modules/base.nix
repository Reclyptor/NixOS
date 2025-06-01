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
    neovim
    nmap
    oh-my-posh
    openssl
    talosctl
    wget
    xclip
    yt-dlp
  ];
}
