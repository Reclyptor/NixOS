{ config, pkgs, lib, ... }: {
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    
    age = {
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      sshKeyPaths = [];
    };

    secrets = {
      "bash/gcp-mysql-host" = {
        path = "${config.home.homeDirectory}/.config/sops/secrets/bash/gcp-mysql-host";
      };
      "bash/gcp-mysql-ca-cert" = {
        path = "${config.home.homeDirectory}/.config/sops/secrets/bash/gcp-mysql-ca-cert";
      };
      "bash/gcp-mysql-client-cert" = {
        path = "${config.home.homeDirectory}/.config/sops/secrets/bash/gcp-mysql-client-cert";
      };
      "bash/gcp-mysql-client-key" = {
        path = "${config.home.homeDirectory}/.config/sops/secrets/bash/gcp-mysql-client-key";
      };
      "bash/k3s-host" = {
        path = "${config.home.homeDirectory}/.config/sops/secrets/bash/k3s-host";
      };
      "bash/k3s-mysql-password" = {
        path = "${config.home.homeDirectory}/.config/sops/secrets/bash/k3s-mysql-password";
      };
      "bash/k3s-mongodb-password" = {
        path = "${config.home.homeDirectory}/.config/sops/secrets/bash/k3s-mongodb-password";
      };
      "bash/atlas-mongodb-host" = {
        path = "${config.home.homeDirectory}/.config/sops/secrets/bash/atlas-mongodb-host";
      };
    };
  };
}

