# Every entry here mounts a DATASET ROOT and never an individual child
# dataset, and that is a privacy rule before it is a technical one.
#
# The NAS exports each media category under a root as its own ZFS dataset, and
# NFSv4 crosses into an exported child on first access — the client builds the
# submount itself. So enumerating the children would buy nothing: they are all
# reachable through the root regardless. What enumerating them WOULD do is
# write every category name into this file, and this repository is public.
# Mounting only the root keeps the shape of what is stored off the internet.
#
# Mountpoints are <host>/<dataset> so a second dataset on the same NAS has
# somewhere to land. dxp4800's videos used to sit at the bare /data/nfs/dxp4800,
# which left a sibling nowhere to go except inside the videos dataset itself.
_: {
  flake.modules.nixos.workstation = _: {
    fileSystems."/data/nfs/dxp6800/videos" = {
      device = "192.168.1.2:/mnt/primary/videos";
      fsType = "nfs4";
      options = [
        "defaults"
        "_netdev"
        "x-systemd.automount"
      ];
    };

    # videos and images are siblings under primary, not children of one
    # another, so each needs its own entry. Their categories do not.
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
