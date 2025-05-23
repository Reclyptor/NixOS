{ config, pkgs, ... }:
let driver = config.boot.kernelPackages.nvidiaPackages.beta; in {
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  environment.systemPackages = with pkgs; [
    libdecor
    libglvnd
    libGL
    mesa-demos
  ];

  boot.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
    "i2c-nvidia_gpu"
  ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      package = driver;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
      ];
    };

    nvidia = {
      open = false;
      nvidiaSettings = true;
      modesetting.enable = true;
      package = driver;
      powerManagement = {
        enable = false;
        finegrained = false;
      };
    };
  };
}
