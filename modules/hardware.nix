{ config, pkgs, ... }: {
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    nvidia = {
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      modesetting.enable = true;
      powerManagement.enable = false;
    };

    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        vulkan-loader
        vulkan-tools
        vulkan-validation-layers
        libvdpau
      ];
      extraPackages32 = with pkgs; [
        vulkan-loader
        libvdpau
      ];
    };

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
