{ ... }: {
  flake.modules.nixos.workstation = { config, pkgs, ... }: {
    networking.hostName = "nixos";
    networking.hostId = "bca3551f";
    networking.networkmanager.enable = true;
    networking.networkmanager.wifi.powersave = false;
    networking.firewall.enable = true;
    environment.systemPackages = with pkgs; [
      networkmanagerapplet
    ];
  };
}
