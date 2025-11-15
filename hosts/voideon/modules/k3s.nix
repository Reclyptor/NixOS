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
    role = "agent";
    serverAddr = "https://192.168.1.10:6443";
    tokenFile = config.sops.secrets."k3s/token".path;
    extraFlags = [ ];
  };

  networking.firewall = {
    allowedTCPPorts = [ 10250 3260 ];
    allowedUDPPorts = [ 8472 ];
  };
}

