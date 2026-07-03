{ config, inputs, lib, ... }: {
  # Hosts register themselves here (modules/hosts/*.nix); this glue turns each
  # entry into a nixosConfigurations output. sops-nix is wired for every host.
  options.configurations.nixos = lib.mkOption {
    description = "NixOS hosts, each a deferred module composing feature modules.";
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
  };

  config.flake.nixosConfigurations = builtins.mapAttrs
    (name: module: inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        { networking.hostName = lib.mkDefault name; }
        inputs.sops-nix.nixosModules.sops
        module
      ];
    })
    config.configurations.nixos;
}
