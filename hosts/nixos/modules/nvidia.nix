{ config, ... }: {
  nixpkgs.config.nvidia.acceptLicense = true;
  nixpkgs.config.allowUnfree = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  # Load NVIDIA modules early for stable KMS bring-up.
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.blacklistedKernelModules = [ "nouveau" ];
  boot.kernelParams = [
    "module_blacklist=nouveau"
    "modprobe.blacklist=nouveau"
    "rd.driver.blacklist=nouveau"
  ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    nvidia = {
      open = true; # Required for Blackwell (RTX 50xx)
      modesetting.enable = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
    };
  };
}
