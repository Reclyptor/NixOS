{ config, pkgs, ... }: {
  services.pcscd = {
    enable = true;
    plugins = [ pkgs.ccid ];
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
  ];

  security.apparmor.enable = true;

  security.sudo.extraConfig = ''
    Defaults lecture=never
    Defaults timestamp_timeout=30
  '';
}
