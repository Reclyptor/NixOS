{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    eza
    fastfetch
    git
    gnupg
    neovim
    oh-my-posh
    wget
    yt-dlp
  ];
}
