{ config, pkgs, ... }: {
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 3;
  boot.tmp.cleanOnBoot = true;
}
