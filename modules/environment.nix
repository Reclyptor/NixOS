{ config, pkgs, ... }: {
  environment.variables = {
    EDITOR = "nvim";
    GTK_THEME = "Adwaita-dark";
    QT_STYLE_OVERRIDE = "Adwaita-dark";
  };

  environment.sessionVariables = {
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    XDG_SESSION_TYPE = "wayland";
    DEFAULT_BROWSER = "${pkgs.brave}/bin/brave";
  };
}
