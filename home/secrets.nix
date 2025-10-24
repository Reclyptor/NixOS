{ config, pkgs, lib, ... }: {
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    
    age = {
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    };

    secrets = {
      "bash/gcp-mysql-host" = {
        path = "${config.home.homeDirectory}/.config/sops/secrets/bash/gcp-mysql-host";
      };
      "bash/atlas-mongodb-host" = {
        path = "${config.home.homeDirectory}/.config/sops/secrets/bash/atlas-mongodb-host";
      };
    };
  };
}

