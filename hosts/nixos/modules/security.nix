{ config, pkgs, ... }: {
  services.pcscd = {
    enable = true;
    plugins = [ pkgs.ccid ];
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  environment.systemPackages = with pkgs; [
    age
    age-plugin-yubikey
    gnupg
    openssl
    opensc
    sops
    ssh-to-age
  ];

  security.apparmor.enable = true;

  security.sudo.extraConfig = ''
    Defaults lecture=never
    Defaults timestamp_timeout=30
  '';
}
