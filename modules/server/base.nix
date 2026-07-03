{ ... }: {
  flake.modules.nixos.server = { config, lib, pkgs, ... }: {
    system.stateVersion = "25.05";
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    boot.kernelModules = [
      "iscsi_tcp"
    ] ++ (if config.host.gpu == "amd" then [
      "amdgpu"
      "kvm-amd"
    ] else [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
      "kvm-intel"
    ]) ++ [
      "sr_mod"
      "cdrom"
      "sg"
    ];
    boot.kernelParams =
      if config.host.gpu == "amd"
      then [ "amdgpu.dc=1" "amdgpu.dpm=1" ]
      else [ "nvidia-drm.modeset=1" ];
    boot.extraModprobeConfig = lib.mkIf (config.host.gpu == "nvidia") "options nvidia_drm modeset=1";
    boot.supportedFilesystems = [ "zfs" "nfs" ];

    networking.hostId = config.host.hostId;
    networking.hosts = {
      "192.168.1.10" = [ "archeon" ];
      "192.168.1.11" = [ "fluxeon" ];
      "192.168.1.12" = [ "voideon" ];
      "192.168.1.13" = [ "styxeon" ];
      "192.168.1.14" = [ "bytheon" ];
    };
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

    environment.systemPackages = [ pkgs.kitty.terminfo ];
  };
}
