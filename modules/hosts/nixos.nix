{ config, inputs, ... }: {
  configurations.nixos.nixos = {
    imports = [
      ../../hardware/nixos.nix
      config.flake.modules.nixos.workstation
      inputs.home-manager.nixosModules.home-manager
    ];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.reclyptor.imports = [ config.flake.modules.homeManager.base ];
      sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
    };
  };
}
