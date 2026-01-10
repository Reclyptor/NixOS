{ config, pkgs, ... }:
let driver = config.boot.kernelPackages.nvidiaPackages.beta; in {
  nixpkgs.config.nvidia.acceptLicense = true;
  nixpkgs.config.allowUnfree = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __GL_VRR_ALLOWED = "1";
    __GL_GSYNC_ALLOWED = "1";
  };

  environment.systemPackages = with pkgs; [
    libdecor
    mesa-demos
    nvidia-vaapi-driver
    libva-utils
  ];

  boot.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];
  boot.extraModprobeConfig = "options nvidia_drm modeset=1";

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      package = driver;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        libvdpau-va-gl
        libGL
        xorg.libXrandr
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        nvidia-vaapi-driver
        libvdpau-va-gl
        libGL
        xorg.libXrandr
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
