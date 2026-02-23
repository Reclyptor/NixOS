{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [ blueman ];
  services.blueman.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
