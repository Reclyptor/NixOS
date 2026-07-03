{ ... }: {
  flake.modules.nixos.workstation = { config, pkgs, ... }: {
    networking.hostName = "nixos";
    networking.hostId = "bca3551f";
    networking.networkmanager.enable = true;
    networking.firewall.enable = true;
    environment.systemPackages = with pkgs; [
      networkmanagerapplet
    ];
  };
}
