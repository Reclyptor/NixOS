{ config, ... }:
{
  # Everything that actually differs between the five cluster nodes lives in
  # this option; the rest of modules/server/ is shared verbatim.
  #
  # The schema is not declared here — it is the same node type the fleet
  # inventory uses (modules/flake/fleet.nix), so a field is defined once and is
  # simultaneously part of the fleet data and of what a server module can read.
  # Each host file sets `host` to its entry in fleet.nodes.
  flake.modules.nixos.server =
    { lib, ... }:
    {
      options.host = lib.mkOption {
        type = config.fleet.nodeType;
        description = "This node's entry from the fleet inventory.";
      };
    };
}
