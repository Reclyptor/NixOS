{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    eza
    fastfetch
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
