{ config, pkgs, ... }: {
  environment.variables = {
  };

  environment.sessionVariables = {
    EDITOR = "nvim";
    DEFAULT_BROWSER = "${pkgs.brave}/bin/brave";
    GBM_BACKEND = "nvidia-drm";
    GTK_THEME = "Adwaita-dark";
    LIBVA_DRIVER_NAME = "nvidia";
    NIXOS_OZONE_WL = "1";
    QT_STYLE_OVERRIDE = "Adwaita-dark";
    WINE_FULLSCREEN_FSR= "1";
    WINE_FULLSCREEN_FSR_STRENGTH= "2";
    WINE_VIRTUAL_DESKTOP= "0";
    WLR_NO_HARDWARE_CURSORS = "1";
    XDG_SESSION_TYPE = "wayland";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __GL_GSYNC_ALLOWED = "0";
    __GL_VRR_ALLOWED = "0";
  };
}
