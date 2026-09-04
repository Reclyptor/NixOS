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
    # No x-systemd.automount: this sits inside the automounted parent, and a
    # nested automount stacks its autofs trigger on top of the NFS mount it
    # just made, shadowing it — lookups then fail with ELOOP. systemd orders
    # this after the parent on its own. nofail keeps a sleeping NAS from
    # holding up boot.
    fileSystems."/data/nfs/dxp4800/movies" = {
      device = "192.168.1.3:/mnt/primary/videos/movies";
      fsType = "nfs4";
      options = [
        "defaults"
        "_netdev"
        "nofail"
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
