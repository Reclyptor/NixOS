{ config, pkgs, ... }: {
  environment.variables = {
    LIBVA_DRIVER_NAME = "nvidia";
    VDPAU_DRIVER = "nvidia";
  };

  environment.sessionVariables = {
    EDITOR = "nvim";
    DEFAULT_BROWSER = "${pkgs.brave}/bin/brave";

    # Wayland / SDL / Qt
    NIXOS_OZONE_WL = "1";
    XDG_SESSION_TYPE = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    LIBDECOR_ENABLE = "1";
    WLR_NO_HARDWARE_CURSORS = "1";

    # Vulkan runtime
    VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";
    VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/etc/vulkan/explicit_layer.d";

    # NVIDIA-specific
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __GL_VRR_ALLOWED = "1";
    __GL_GSYNC_ALLOWED = "1";
    __VK_LAYER_NV_optimus = "NVIDIA_only";
    WLR_RENDERER_ALLOW_SOFTWARE = "1";

    # Steam/Proton
    STEAM_RUNTIME = "1";
    ENABLE_GAMESCOPE_WSI = "1";

    # Wine
    WINE_FULLSCREEN_FSR= "1";
    WINE_FULLSCREEN_FSR_STRENGTH= "2";
    WINE_VIRTUAL_DESKTOP= "0";
  };
}
