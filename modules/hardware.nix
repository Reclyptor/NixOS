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
        vulkan-validation-layers
	vulkan-extension-layer
        vulkan-tools
	libvdpau
        vaapiVdpau
        libglvnd
      ];
      extraPackages32 = with pkgs; [
        vulkan-loader
        vulkan-validation-layers
	vulkan-extension-layer
        vulkan-tools
	libvdpau
        vaapiVdpau
        libglvnd
      ];
    };

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
