_: {
  # fleet-rebuild (home/fleet-rebuild.nix) drives every node from the
  # workstation with `nixos-rebuild --target-host --elevate sudo`, in parallel,
  # with no terminal to type a password into.
  #
  # This is deliberately the whole of wheel and not a rule for "rebuild
  # commands": what the node is asked to run is `nix-env --set` on the system
  # profile and `systemd-run … switch-to-configuration` from a store path, and
  # whoever may run those can activate any system at all. A narrow rule would
  # read as a limit while granting root anyway. The gate is the SSH key, which
  # lives on the YubiKey; password logins are off in ssh.nix.
  flake.modules.nixos.server = _: {
    security.sudo.wheelNeedsPassword = false;
  };
}
