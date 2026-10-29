# EffectCraft — the After Effects equivalent.
#
# The only app in the suite built on another app's crates: its lockfile takes
# filmcraft's codec crates from git at a fixed rev rather than from crates.io.
# fetchCargoVendor resolves git sources itself, so that needs no outputHashes —
# but it does mean this app's vendor hash moves whenever upstream re-points that
# rev, independently of its own release tag.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "effectcraft";
          version = "0.18.0";
          hash = "sha256-5TDL98KE2j9blT8FeqMOTUznhfdJNOO+exn4LJcth58=";
          cargoHash = "sha256-PxW3amIo5yA2jlupIUePFTx72tdfcmXcyK0/eC79KTM=";
          releaseDate = "2026-10-28";
          description = "Motion graphics and visual effects compositor";

          # Same ALSA path as filmcraft, whose media crates it shares.
          extraNativeBuildInputs = [ pkgs.pkg-config ];
          extraBuildInputs = [ pkgs.alsa-lib ];
        })
      ];
    };
}
