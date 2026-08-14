{ ... }: {
  # Resolves interpreters for unpackaged dynamic binaries. The claude-code
  # overlay's wrapper depends on this. Add libraries here if some binary turns
  # out to need more than nix-ld's defaults.
  flake.modules.nixos.workstation = { ... }: {
    programs.nix-ld.enable = true;
  };
}
