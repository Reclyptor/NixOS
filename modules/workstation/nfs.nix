_: {
  flake.modules.nixos.workstation = _: {
    fileSystems."/data/nfs/dxp6800" = {
      device = "192.168.1.2:/mnt/primary/videos";
      fsType = "nfs4";
      options = [
        "defaults"
        "_netdev"
        "x-systemd.automount"
      ];
    };

    # dxp4800 keeps each top-level media kind in its own ZFS dataset, and those
    # are siblings under primary — not children of one another — so each needs
    # its own mount. They are mounted at <host>/<dataset>, matching flashstor
    # below; videos used to sit at the bare /data/nfs/dxp4800, which left no
    # path for a sibling to occupy without landing inside the videos dataset.
    #
    # Within a dataset the old note still holds: NFSv4 crosses into a child
    # dataset when the NAS exports it and the client creates the submount
    # itself, so the per-category datasets under videos/ and images/ need no
    # entry of their own here.
    fileSystems."/data/nfs/dxp4800/videos" = {
      device = "192.168.1.3:/mnt/primary/videos";
      fsType = "nfs4";
      options = [
        "defaults"
        "_netdev"
        "x-systemd.automount"
      ];
    };

    fileSystems."/data/nfs/dxp4800/images" = {
      device = "192.168.1.3:/mnt/primary/images";
      fsType = "nfs4";
      options = [
        "defaults"
        "_netdev"
        "x-systemd.automount"
      ];
    };

    fileSystems."/data/nfs/flashstor/videos" = {
      device = "192.168.1.4:/mnt/primary/videos";
      fsType = "nfs4";
      options = [
        "defaults"
        "_netdev"
        "x-systemd.automount"
      ];
    };

    fileSystems."/data/nfs/flashstor/data" = {
      device = "192.168.1.4:/mnt/primary/data";
      fsType = "nfs4";
      options = [
        "defaults"
        "_netdev"
        "x-systemd.automount"
      ];
    };

    fileSystems."/data/nfs/asustor" = {
      device = "192.168.1.5:/volume1/data";
      fsType = "nfs4";
      options = [
        "defaults"
        "_netdev"
        "x-systemd.automount"
      ];
    };
  };
}
