_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        # nixpkgs' own package, patched. It used to come from herdr's flake,
        # pinned to a tag while nixpkgs trailed by two releases; nixpkgs has
        # since passed that pin, and herdr's flake builds in a second nixpkgs
        # evaluation with its own Rust toolchain, which compiled gtk3, pygobject
        # and libsecret here for nothing.
        #
        # The patches teach herdr about dsh, which it cannot learn any other way:
        # agents are identified against a compiled-in enum, so a local manifest
        # override under ~/.config/herdr/agent-detection/ can only patch rules for
        # an id the binary already knows. They add no dependency, so nothing
        # re-vendors. Offered upstream; delete this once it ships.
        herdr = prev.herdr.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ./deepseek-agent.patch
            ./pane-sync.patch
          ];
        });
      })
    ];
  };
}
