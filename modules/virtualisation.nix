{ config, pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    docker
  ];

  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };
}
