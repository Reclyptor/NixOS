{ config, pkgs, ... }: {
  services.openssh.enable = true;

  services.openiscsi.enable = true;
  services.openiscsi.name = "iqn.2005-10.org.freenas.ctl";

  systemd.tmpfiles.rules = [
    "d /usr/sbin 0755 root root -"
    "L+ /usr/sbin/iscsiadm - - - - /run/current-system/sw/bin/iscsiadm"
    "d /sbin 0755 root root -"
    "L+ /sbin/iscsiadm - - - - /run/current-system/sw/bin/iscsiadm"
    "d /dev/dri 0755 root video -"
    "d /var/lib/plex-transcode 0755 root root -"
  ];

  systemd.services.k3s.after = [ "iscsid.service" ];
  systemd.services.k3s.requires = [ "iscsid.service" ];
}
