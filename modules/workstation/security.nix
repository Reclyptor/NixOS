_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      age
      openssl
      sops
      ssh-to-age
    ];

    security.apparmor.enable = true;

    security.sudo.extraConfig = ''
      Defaults lecture=never
      Defaults timestamp_timeout=30
    '';
  };
}
