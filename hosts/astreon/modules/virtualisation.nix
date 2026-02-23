{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    docker
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
}
