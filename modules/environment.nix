{ config, pkgs, ... }: {
  environment.variables = {
  };

  environment.sessionVariables = {
    EDITOR = "nvim";
    DEFAULT_BROWSER = "${pkgs.brave}/bin/brave";
    LIBVA_DRIVER_NAME = "nvidia";
    NIXOS_OZONE_WL = "1";
    WINE_FULLSCREEN_FSR= "1";
    WINE_FULLSCREEN_FSR_STRENGTH= "2";
    WINE_VIRTUAL_DESKTOP= "0";
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
