{ ... }: {
  # SSH policy for the cluster. This lived as a bare `services.openssh.enable`
  # line inside iscsi.nix — a module about iSCSI — which is why it went years
  # without anyone hardening it: nobody reviewing SSH policy would look there.
  #
  # Key auth is already deployed via users.users.reclyptor.openssh.authorizedKeys
  # and was verified working on all five nodes before this was turned on, so
  # passwords were pure attack surface. users.mutableUsers is true, meaning the
  # account password is whatever was last set imperatively with passwd.
  #
  # PermitRootLogin is deliberately left at its "prohibit-password" default:
  # root has no authorizedKeys entry, so root SSH is already effectively closed,
  # and tightening it to "no" gains nothing real while removing a recovery
  # avenue on a change whose failure mode is lockout.
  flake.modules.nixos.server = { ... }: {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };
}
