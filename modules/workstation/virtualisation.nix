_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      docker-compose
    ];

    virtualisation.docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };
}
