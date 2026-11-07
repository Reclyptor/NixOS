_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    system.stateVersion = "25.11";
    nix.package = pkgs.nixVersions.nix_2_34;
    # experimental-features is set in common/nix.nix.
    nix.settings.warn-dirty = false;
    nix.gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
    nix.optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
    nix.daemonCPUSchedPolicy = "batch";
    nix.daemonIOSchedClass = "idle";
    # Thread policies only order threads inside a cgroup; system.slice still
    # gets an equal share with user.slice. An idle slice at the cgroup root
    # makes builds yield to games, and MemoryHigh reclaims build memory before
    # anything else gets swapped. No MemoryMax: throttle builds, never kill them.
    systemd.slices.nix-build.sliceConfig = {
      CPUWeight = "idle";
      MemoryHigh = "40%";
    };
    systemd.services.nix-daemon.serviceConfig.Slice = "nix-build.slice";
    services.zfs.autoScrub.enable = true;
    services.zfs.trim.enable = true;
    zramSwap.enable = true;
  };
}
