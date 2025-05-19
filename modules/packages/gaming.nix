{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    steam
    mangohud
    gamescope
    protonup-qt
    libdecor
  ];
}
