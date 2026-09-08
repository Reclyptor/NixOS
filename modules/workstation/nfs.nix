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

    # Each media category on dxp4800 is its own ZFS dataset. NFSv4 crosses into
    # a child dataset when that child is exported on the NAS, and the client
    # creates the submount itself — so this one mount reaches all of them and
    # no per-dataset entry belongs here.
    fileSystems."/data/nfs/dxp4800" = {
      device = "192.168.1.3:/mnt/primary/videos";
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
