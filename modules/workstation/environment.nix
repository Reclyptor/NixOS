{ ... }: {
  flake.modules.nixos.workstation = { config, pkgs, ... }: {
    environment.sessionVariables = {
      EDITOR = "nvim";
      BROWSER = "zen-beta";
      DEFAULT_BROWSER = "${pkgs.zen-browser}/bin/zen-beta";
    };
  };
}
