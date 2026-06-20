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
    # Workaround for Cilium DNS proxy + WireGuard incompatibility:
    # https://github.com/cilium/cilium/issues/45837
    #
    # Pods use node-local-dns so Cilium's L7 DNS proxy forwards upstream queries
    # to a same-node hostNetwork resolver instead of sending proxy-originated DNS
    # traffic across WireGuard to a remote CoreDNS pod. If Cilium fixes host-netns
    # DNS proxy reply handling over WireGuard, this can be reverted to kube-dns
    # (10.43.0.10) and the node-local-dns/firewall workaround can be removed.
    clusterDnsIP = "169.254.20.10";
    commonSpecialArgs = { inherit inputs clusterDnsIP; };
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = commonSpecialArgs;
      modules = [
        ./hosts/nixos/configuration.nix
        ./hosts/nixos/hardware-configuration.nix
        sops-nix.nixosModules.sops
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
      specialArgs = commonSpecialArgs;
      modules = [
        ./hosts/archeon/configuration.nix
        ./hosts/archeon/hardware-configuration.nix
        sops-nix.nixosModules.sops
      ];
    };

    nixosConfigurations.fluxeon = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = commonSpecialArgs;
      modules = [
        ./hosts/fluxeon/configuration.nix
        ./hosts/fluxeon/hardware-configuration.nix
        sops-nix.nixosModules.sops
      ];
    };

    nixosConfigurations.voideon = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = commonSpecialArgs;
      modules = [
        ./hosts/voideon/configuration.nix
        ./hosts/voideon/hardware-configuration.nix
        sops-nix.nixosModules.sops
      ];
    };

    nixosConfigurations.styxeon = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = commonSpecialArgs;
      modules = [
        ./hosts/styxeon/configuration.nix
        ./hosts/styxeon/hardware-configuration.nix
        sops-nix.nixosModules.sops
      ];
    };

    nixosConfigurations.bytheon = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = commonSpecialArgs;
      modules = [
        ./hosts/bytheon/configuration.nix
        ./hosts/bytheon/hardware-configuration.nix
        sops-nix.nixosModules.sops
      ];
    };
  };
}
