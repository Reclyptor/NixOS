{ config, pkgs, ... }: {
  services.gnome.gnome-keyring.enable = true;

  security.pam.services.greetd.enableGnomeKeyring = true;

  # Prevent gcr-ssh-agent from hijacking SSH_AUTH_SOCK — gpg-agent handles SSH
  systemd.user.services.gcr-ssh-agent.enable = false;
  systemd.user.sockets.gcr-ssh-agent.enable = false;

  environment.systemPackages = with pkgs; [
    libsecret
  ];
}
