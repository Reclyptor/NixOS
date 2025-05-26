{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    eza
    fastfetch
    ffmpeg-full
    git
    gnupg
    jq
    neovim
    nmap
    oh-my-posh
    wget
    xclip
    yt-dlp
  ];
}
