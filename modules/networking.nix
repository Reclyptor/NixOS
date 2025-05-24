{ config, pkgs, ... }: {
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  environment.systemPackages = with pkgs; [
    networkmanagerapplet
  ];
}
