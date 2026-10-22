{ inputs, ... }:

# Nix daemon settings shared by every machine.
let
  common = _: {
    nixpkgs.config.allowUnfree = true;

    nix = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];

        # Each package may use every core. Running several all-core packages at
        # once exhausts memory (kernel OOM killed cc1plus and rustc during
        # parallel rebuilds on the workstation and the cluster nodes). Keep
        # package builds serial while leaving all cores available per package.
        max-jobs = 1;
        cores = 0;
      };

      # Without this, `nix shell nixpkgs#foo` and `<nixpkgs>` resolve against
      # whatever the channel/registry last fetched — a completely different
      # nixpkgs from the one this flake is locked to, which then downloads and
      # evaluates a second tree. Pinning both to the flake's own input makes
      # ad-hoc commands agree with the system.
      registry.nixpkgs.flake = inputs.nixpkgs;
      nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    };
  };
in
{
  flake.modules.nixos.server = common;
  flake.modules.nixos.workstation = common;
}
