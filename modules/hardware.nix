{ config, pkgs, ... }: {
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
	mesa
        vulkan-loader
        vulkan-tools
        vulkan-validation-layers
      ];
      extraPackages32 = with pkgs; [
	libGL
        libglvnd
        vulkan-loader
      ];
    };

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
