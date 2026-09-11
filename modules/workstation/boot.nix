_: {
  flake.modules.nixos.workstation = _: {
    boot.loader.systemd-boot = {
      enable = true;
      configurationLimit = 5;
    };
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.timeout = 3;
    boot.tmp.cleanOnBoot = true;
    boot.supportedFilesystems.zfs = true;
    boot.zfs.forceImportRoot = false;
    # The ARC defaults to all but a gigabyte of RAM and gives it back slowly,
    # so on a 62 GB workstation it sat at 25 GB while 10 GB of the desktop
    # had been pushed into zram. 16 GB is plenty of read cache for three
    # pools whose hot set is the nix store and the home directory.
    boot.kernelParams = [ "zfs.zfs_arc_max=17179869184" ];
    boot.zfs.extraPools = [
      "npool"
      "spool"
    ];
  };
}
