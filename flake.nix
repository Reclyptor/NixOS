{
  description = "NixOS System Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, ... }@inputs: 
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
    homeConfigurations."nixos" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./home.nix
        sops-nix.homeManagerModules.sops
      ];
      extraSpecialArgs = { inherit inputs; };
    };

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/nixos/configuration.nix
        ./hosts/nixos/hardware-configuration.nix
      	home-manager.nixosModules.home-manager {
      	  home-manager = {
      	    useGlobalPkgs = true;
      	    useUserPackages = true;
      	    users.reclyptor = import ./home.nix;
      	    extraSpecialArgs = { inherit inputs; };
      	    sharedModules = [ sops-nix.homeManagerModules.sops ];
      	  };
      	}
      ];
    };

    nixosConfigurations.archeon = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/archeon/configuration.nix
        ./hosts/archeon/hardware-configuration.nix
        sops-nix.nixosModules.sops
      ];
    };

    nixosConfigurations.fluxeon = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/fluxeon/configuration.nix
        ./hosts/fluxeon/hardware-configuration.nix
        sops-nix.nixosModules.sops
      ];
    };

    nixosConfigurations.voideon = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/voideon/configuration.nix
        ./hosts/voideon/hardware-configuration.nix
        sops-nix.nixosModules.sops
      ];
    };
  };
}
