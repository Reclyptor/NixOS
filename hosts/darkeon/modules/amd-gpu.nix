{ config, pkgs, ... }: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      mesa.drivers
      vaapiVdpau
      libvdpau-va-gl
      rocmPackages.clr.icd
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      mesa.drivers
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "radeonsi";
    ROC_ENABLE_PRE_VEGA = "1";
    AMD_VULKAN_ICD = "RADV";
    RADV_PERFTEST = "gpl";
  };

  users.groups.video = {};
  users.groups.render = {};
}
