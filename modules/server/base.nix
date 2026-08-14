{ ... }: {
  flake.modules.nixos.server = { config, lib, pkgs, ... }: {
    system.stateVersion = "25.05";

    boot.loader.systemd-boot.enable = true;
    # Bounds boot ENTRIES; nix.gc (maintenance.nix) bounds store GENERATIONS.
    # Both are needed — without this the vfat ESP fills with kernels until a
    # nixos-rebuild switch fails partway through.
    boot.loader.systemd-boot.configurationLimit = 10;
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
    boot.zfs.forceImportRoot = false;

    networking.hostId = config.host.hostId;
    networking.hosts = {
      "192.168.1.10" = [ "archeon" ];
      "192.168.1.11" = [ "fluxeon" ];
      "192.168.1.12" = [ "voideon" ];
      "192.168.1.13" = [ "styxeon" ];
      "192.168.1.14" = [ "bytheon" ];
    };
    networking.networkmanager.enable = true;

    # Timezone/locale/xkb live in common/locale.nix; allowUnfree and the nix
    # daemon settings in common/nix.nix.
    environment.systemPackages = [ pkgs.kitty.terminfo ];
  };
}
