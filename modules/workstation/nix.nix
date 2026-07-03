{ ... }: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    system.stateVersion = "25.11";
    nix.package = pkgs.nixVersions.nix_2_34;
    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
    };
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
    services.zfs.autoScrub.enable = true;
    services.zfs.trim.enable = true;
    zramSwap.enable = true;
  };
}
