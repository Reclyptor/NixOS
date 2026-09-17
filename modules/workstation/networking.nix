_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    networking.hostName = "nixos";
    networking.hostId = "bca3551f";
    networking.networkmanager.enable = true;
    networking.networkmanager.wifi.powersave = false;
    networking.firewall.enable = true;
    # mtr needs raw sockets; this wrapper grants them so it works unprivileged.
    programs.mtr.enable = true;
    environment.systemPackages = with pkgs; [
      networkmanagerapplet
    ];
  };
}
