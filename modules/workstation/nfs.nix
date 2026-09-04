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

    fileSystems."/data/nfs/dxp4800" = {
      device = "192.168.1.3:/mnt/primary/videos";
      fsType = "nfs4";
      options = [
        "defaults"
        "_netdev"
        "x-systemd.automount"
      ];
    };

    # movies is its own dataset on the NAS, and NFS does not cross a dataset
    # boundary — mounting only the parent shows an empty directory here.
    #
    # Nested inside the automounted parent, so a `nixos-rebuild switch` can
    # leave its autofs trigger stacked on top of the NFS mount it just made,
    # shadowing it: the directory reads empty and `stat -f` fails with ELOOP.
    # A reboot brings it up clean. If it ever shows empty again, check
    # `grep dxp4800 /proc/self/mountinfo` for a stacked autofs before
    # assuming the export went away.
    fileSystems."/data/nfs/dxp4800/movies" = {
      device = "192.168.1.3:/mnt/primary/videos/movies";
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
