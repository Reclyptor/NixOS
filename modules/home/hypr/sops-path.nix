{ ... }: {
  flake.modules.homeManager.base = { pkgs, lib, ... }: {
    # Override sops-nix service environment to include age-plugin-yubikey in PATH
    systemd.user.services.sops-nix.Service.Environment = lib.mkForce "PATH=${lib.makeBinPath [ pkgs.age-plugin-yubikey ]}:/run/current-system/sw/bin";
  };
}
