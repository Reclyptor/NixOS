{ config, pkgs, ... }: {
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    # allowedTCPPorts = [ 80 443 ];
    # allowedUDPPorts = [ ];
    # trustedInterfaces = [ "docker0" ];
  };
  environment.systemPackages = with pkgs; [
    networkmanagerapplet
  ];
}
