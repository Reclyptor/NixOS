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
          version = "0.10.0";
          hash = "sha256-3a5aeR9L6iS1nWdZQPlm+4RmrOIfrHzgzL+tABwctCc=";
          cargoHash = "sha256-Ag4H+W8IPcgTXi/GAYpeDV2qGBYr7sth2uD+QwckTek=";
          releaseDate = "2026-10-14";
          description = "Motion graphics and visual effects compositor";

          # Same ALSA path as filmcraft, whose media crates it shares.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];
        })
      ];
    };
}
