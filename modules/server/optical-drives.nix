_: {
  # The rules themselves are per-node hardware inventory, so they live with the
  # rest of the node's data in modules/flake/fleet.nix — the fleet-standard set
  # is that option's default and styxeon (the ripper node) overrides it there.
  flake.modules.nixos.server =
    { config, ... }:
    {
      services.udev.extraRules = config.host.opticalDriveRules;
    };
}
