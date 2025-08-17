{ config, pkgs, ... }: {
  services.pcscd = {
    enable = true;
    plugins = [ pkgs.ccid ];
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    age
    age-plugin-yubikey
    gnupg
    openssl
    sops
  ];
}
