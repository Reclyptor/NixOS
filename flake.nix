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

  outputs = { self, nixpkgs, home-manager, sops-nix, ... }@inputs: {
    nixosConfigurations.astreon = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/astreon/configuration.nix
        ./hosts/astreon/hardware-configuration.nix
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

    nixosConfigurations.styxeon = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/styxeon/configuration.nix
        ./hosts/styxeon/hardware-configuration.nix
        sops-nix.nixosModules.sops
      ];
    };

    nixosConfigurations.bytheon = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/bytheon/configuration.nix
        ./hosts/bytheon/hardware-configuration.nix
        sops-nix.nixosModules.sops
      ];
    };
  };
}
