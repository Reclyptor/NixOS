_: {
  # Housekeeping the workstation has always had and the cluster never did.
  # Three independent slow failures were queued up without it: unbounded
  # generations on ZFS roots that nothing collects, and five pools that had
  # never been scrubbed, so silent corruption stays invisible until a read
  # fails. (The third — an EFI partition filling with kernels — is bounded by
  # boot.loader.systemd-boot.configurationLimit in base.nix.)
  #
  # Values differ from the workstation's on purpose:
  #   - 30d, not 7d: a cluster node is rebuilt rarely, so rollback headroom is
  #     worth more here than reclaimed disk.
  #   - weekly, not daily: keeps GC I/O off etcd's fsync path most nights.
  #   - monthly scrub: the conventional cadence, and these are NVMe pools.
  flake.modules.nixos.server = _: {
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    nix.optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };

    services.zfs.autoScrub = {
      enable = true;
      interval = "monthly";
    };
  };
}
