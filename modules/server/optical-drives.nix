_: {
  # Per-node hardware inventory lives with the rest of the node's data in
  # modules/flake/fleet.nix; the rules are generated in common/optical-drives.nix.
  # Only styxeon has drives — the other four nodes have none, so they get no
  # udev rules at all rather than rules for hardware they do not have.
  flake.modules.nixos.server =
    { config, ... }:
    {
      opticalDrives = config.host.opticalDrives;
    };
}
