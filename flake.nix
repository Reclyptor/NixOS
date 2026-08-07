{
  description = "NixOS System Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Overlay sources tracked as inputs so `nix flake update` bumps them
    # instead of us hand-pasting a version and hash on every release.
    yt-dlp = {
      url = "github:yt-dlp/yt-dlp";
      flake = false;
    };
  };

  # Dendritic pattern (https://github.com/mightyiam/dendritic): every file under
  # modules/ is a flake-parts module, auto-imported by import-tree. Features
  # contribute NixOS/home-manager pieces via flake.modules.<class>.<name>; hosts
  # compose those pieces under modules/hosts/.
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
