{ ... }: {
  # System-level sops root of trust. This used to live inside wireguard.nix,
  # which meant a feature module silently owned a host-wide security setting —
  # nobody auditing secret handling would think to look there.
  #
  # The identity here is the private half of the &nixos recipient in .sops.yaml
  # (age1kl5r8agkag633lhsk8mk3f7qjrrfj3dyg66vfa58pp45ukf23f6quhlh8a). It used to
  # be read straight out of ~/.config/sops/age/keys.txt, so root's decryption was
  # gated on a file the user — or anything running as them — could replace, and
  # that file was mode 0644. Same key, same recipient, no re-encryption needed:
  # only the copy root reads has moved somewhere root actually owns.
  #
  # PROVISIONING (one-time, out of band). A private key cannot be committed to
  # the repo it decrypts, so this file is bootstrap material:
  #
  #   sudo install -D -m 0400 -o root -g root \
  #     <(grep '^AGE-SECRET-KEY' ~/.config/sops/age/keys.txt) \
  #     /var/lib/sops-nix/key.txt
  #
  # Without it sops-nix.service fails at boot and /run/secrets stays empty.
  # Nothing else breaks — boot and login are unaffected.
  flake.modules.nixos.workstation = { ... }: {
    sops = {
      defaultSopsFile = ../../secrets/secrets.yaml;

      age = {
        # This host runs no sshd, so /etc/ssh/ssh_host_ed25519_key does not
        # exist and the usual host-key path is unavailable. sops-nix asserts
        # that at least one key source is configured, hence the explicit file.
        sshKeyPaths = [ ];
        keyFile = "/var/lib/sops-nix/key.txt";

        # Must stay false. `true` mints a NEW keypair at the path above, which
        # is not the &nixos recipient, and every secret then fails to decrypt.
        generateKey = false;
      };
    };
  };
}
