{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    gamescope
    protonup-qt
    steam
  ];
}
