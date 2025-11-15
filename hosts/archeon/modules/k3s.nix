{ config, pkgs, ... }: {
  sops = {
    defaultSopsFile = ../../../secrets/secrets.yaml;
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
    secrets."k3s/token" = { };
  };

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    tokenFile = config.sops.secrets."k3s/token".path;
  };

  networking.firewall = {
    allowedTCPPorts = [ 6443 9345 10250 3260 ];
    allowedUDPPorts = [ 8472 ];
  };
}

