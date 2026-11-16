# EffectCraft — the After Effects equivalent.
#
# The only app in the suite built on another app's crates: its lockfile takes
# filmcraft's codec crates from git at a fixed rev rather than from crates.io.
# fetchCargoVendor resolves git sources itself, so that needs no outputHashes —
# but it does mean this app's vendor hash moves whenever upstream re-points that
# rev, independently of its own release tag.
_: {
  flake.modules.nixos.workstation = import ./_app.nix "effectcraft" (
    { pkgs, ... }: {
      version = "0.24.1";
      hash = "sha256-dtqPop1xmtd/duzJt02QCZj5zrtVtyvUI8hj4TbeSkc=";
      cargoHash = "sha256-TyxQTE247lH2Q1vUJQZudrYSHx7DS+DF5ZfbUUpB/XI=";
      releaseDate = "2026-11-12";
      description = "Motion graphics and visual effects compositor";

      # Same ALSA path as filmcraft, whose media crates it shares.
      extraNativeBuildInputs = [ pkgs.pkg-config ];
      extraBuildInputs = [ pkgs.alsa-lib ];
    }
  );
}
