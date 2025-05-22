{ config, pkgs, ... }: {
  environment.variables = {
    LIBVA_DRIVER_NAME = "nvidia";
    VDPAU_DRIVER = "nvidia";
  };

  environment.sessionVariables = {
    EDITOR = "nvim";
    DEFAULT_BROWSER = "${pkgs.brave}/bin/brave";

    # Wayland / SDL / Qt
    GBM_BACKEND = "nvidia-drm";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    XDG_SESSION_TYPE = "wayland";
    LIBDECOR_ENABLE = "1";
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_RENDERER_ALLOW_SOFTWARE = "0";

    # NVIDIA
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __GL_VRR_ALLOWED = "1";
    __GL_GSYNC_ALLOWED = "1";
    __GL_GPU = "0";

    # Steam/Proton
    STEAM_RUNTIME = "1";
    ENABLE_GAMESCOPE_WSI = "1";

    # Wine
    WINE_FULLSCREEN_FSR= "1";
    WINE_FULLSCREEN_FSR_STRENGTH= "2";
    WINE_VIRTUAL_DESKTOP= "0";
  };
}
