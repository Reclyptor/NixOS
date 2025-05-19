{ config, pkgs, lib, ... }:

{
  options.custom.gaming.enable = lib.mkEnableOption "Enable gaming environment with NVIDIA Vulkan support";

  config = lib.mkIf config.custom.gaming.enable {

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        vulkan-loader
        vulkan-tools
        vulkan-validation-layers
        libvdpau
      ];
      extraPackages32 = with pkgs; [
        libvdpau
      ];
    };

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    environment.systemPackages = with pkgs; [
      steam
      vulkan-tools
      mangohud
      gamescope
    ];

    environment.sessionVariables = {
      # Wayland
      XDG_SESSION_TYPE = "wayland";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";
      SDL_VIDEODRIVER = "wayland";
      LIBDECOR_ENABLE = "1";
      WLR_NO_HARDWARE_CURSORS = "1";

      # Vulkan - NVIDIA only
      VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";
      VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/etc/vulkan/explicit_layer.d";

      # NVIDIA
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      __GL_VRR_ALLOWED = "1";
      WLR_RENDERER_ALLOW_SOFTWARE = "1";
    };

    environment.variables = {
      LIBVA_DRIVER_NAME = "nvidia";
      VDPAU_DRIVER = "nvidia";
    };
  };
}
