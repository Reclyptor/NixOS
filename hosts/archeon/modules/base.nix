{ config, pkgs, ... }: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelModules = [ 
    "iscsi_tcp" 
    "amdgpu" 
    "kvm-amd"
    "sr_mod"
    "cdrom"
    "sg"
  ];
  boot.kernelParams = [ "amdgpu.dc=1" "amdgpu.dpm=1" ];
  boot.supportedFilesystems = [ "zfs" "nfs" ];

  networking.hostId = "00000001";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.xkb = { layout = "us"; variant = ""; };

  nixpkgs.config.allowUnfree = true;
}

