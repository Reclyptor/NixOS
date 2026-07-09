{ ... }: {
  flake.modules.nixos.workstation = { config, pkgs, ... }: {
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
