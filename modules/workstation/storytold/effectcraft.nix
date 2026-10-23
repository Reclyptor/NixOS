# EffectCraft — the After Effects equivalent.
#
# The only app in the suite with an out-of-tree Rust dependency: its lockfile
# takes filmcraft's codec crates from git at a fixed rev rather than from
# crates.io. fetchCargoVendor resolves git sources itself, so that needs no
# outputHashes — but it does mean this app's vendor hash moves whenever upstream
# re-points that rev, independently of its own release tag.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "effectcraft";
          version = "0.16.0";
          hash = "sha256-Qc6DJtbJND79MHsqQsHkPpL+xg622xk4kn4+nYXBpSM=";
          cargoHash = "sha256-BkZjYS5G+mx7F+0ODjEwMn9JBBLG8x58oMGgeBMrT8E=";
          releaseDate = "2026-10-23";
          description = "Motion graphics and visual effects compositor";

          # Same ALSA path as filmcraft, whose media crates it shares.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];
        })
      ];
    };
}
