{ config, pkgs, ... }: {
  services.pcscd = {
    enable = true;
    plugins = [ pkgs.ccid ];
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh = {
    enable = false;
    openFirewall = false;
    settings = {
      X11Forwarding = true;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  environment.systemPackages = with pkgs; [
    age
    age-plugin-yubikey
    gnupg
    openssl
    sops
  ];

  security.apparmor.enable = true;

  security.sudo.extraConfig = ''
    Defaults lecture=never
    Defaults timestamp_timeout=30
  '';
}
