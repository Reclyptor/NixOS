{ config, pkgs, ... }: {
  environment.sessionVariables = {
    EDITOR = "nvim";
    DEFAULT_BROWSER = "${pkgs.brave}/bin/brave";
  };
}
