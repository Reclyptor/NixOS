{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    steam
    mangohud
    gamescope
    vulkan-tools
    protonup-qt
  ];
}
