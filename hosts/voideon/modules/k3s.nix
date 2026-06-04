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
    serverAddr = "https://192.168.1.10:6443";
    tokenFile = config.sops.secrets."k3s/token".path;
    extraFlags = [ "--node-ip" "192.168.1.12" ];
  };

  networking.firewall = {
    allowedTCPPorts = [ 6443 9345 2379 2380 10250 3260 ];
    allowedUDPPorts = [ 8472 ];
  };
}

