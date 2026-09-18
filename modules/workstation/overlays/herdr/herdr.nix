{ inputs, ... }:
{
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (final: _prev: {
        # Straight from the pinned input (which follows our nixpkgs), not
        # upstream's overlays.default — that one composes rust-overlay into the
        # whole package set to build one binary.
        #
        # The patch teaches herdr about dsh, which it cannot learn any other way:
        # agents are identified against a compiled-in enum, so a local manifest
        # override under ~/.config/herdr/agent-detection/ can only patch rules for
        # an id the binary already knows. overrideAttrs keeps upstream's own
        # rustPlatform, zig cache and Cargo.lock — the patch adds no dependency,
        # so nothing re-vendors. Offered upstream; delete this once it ships.
        herdr = inputs.herdr.packages.${final.system}.herdr.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./deepseek-agent.patch ];
        });
      })
    ];
  };
}
