{ ... }: {
  flake.modules.nixos.server = { config, lib, pkgs, ... }: lib.mkIf (config.host.gpu == "amd") {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa
        libva-vdpau-driver
        libvdpau-va-gl
        rocmPackages.clr.icd
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        mesa
        libva-vdpau-driver
        libvdpau-va-gl
      ];
    };

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "radeonsi";
      AMD_VULKAN_ICD = "RADV";
      RADV_PERFTEST = "gpl";
    };
  };
}
