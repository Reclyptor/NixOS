{ ... }: {
  # Everything YubiKey: the smartcard daemon stack, PIV tooling, and the gpg
  # agent that fronts SSH with the on-key credentials.
  #
  # SOPS AGE KEY — HOW IT LIVES ON THE YUBIKEY
  #
  # The kubernetes repo encrypts to the recipient in its .sops.yaml
  # (age1yubikey1q2u7ajmk...). That recipient is a P-256 key sitting in PIV
  # retired slot 82 (RETIRED1, "slot 1" in age-plugin-yubikey speak) of the
  # YubiKey(s) — currently serials 16366431 and 18754047, both holding an
  # imported copy of the same key. ~/.config/sops/age/keys.txt holds a stub
  # (serial + slot + 4-byte tag = sha256 of the compressed pubkey) that tells
  # sops which card to ask for.
  #
  # IMPORTING THE AGE KEY INTO A NEW YUBIKEY
  #
  #   1. Import the private key PEM (from the offline backup) into slot 82:
  #        ykman piv keys import --pin-policy ONCE --touch-policy NEVER 82 age-key.pem
  #   2. Give the slot a certificate — and here is the trap: age-plugin-yubikey
  #      >= 0.5 REJECTS slot certs carrying critical extensions it doesn't
  #      recognize ("A YubiKey stub did not match the YubiKey", and the key
  #      vanishes from --list/--list-all). openssl-minted self-signed certs
  #      include "Basic Constraints: critical, CA:TRUE", which trips exactly
  #      that. Generate the cert with ykman instead — its certs are clean, and
  #      the on-card key self-signs so the private key never leaves the device:
  #        openssl ec -in age-key.pem -pubout > /tmp/age-pub.pem
  #        ykman piv certificates generate -s "CN=age" 82 /tmp/age-pub.pem
  #      (No private-key PEM at hand? Pull the pubkey off a working YubiKey:
  #        ykman piv certificates export 82 - | openssl x509 -pubkey -noout > /tmp/age-pub.pem)
  #   3. Verify the plugin accepts it — this must print the exact recipient
  #      from the kubernetes repo's .sops.yaml:
  #        age-plugin-yubikey --list-all
  #   4. Stubs are per-serial: keys.txt entries for other serials won't match
  #      the new card. Append an identity for it:
  #        age-plugin-yubikey --identity --serial <NEW_SERIAL> >> ~/.config/sops/age/keys.txt
  #   5. Harden the fresh card (they ship with default PIV secrets):
  #        ykman piv access change-management-key --generate --protect
  #        ykman piv access change-puk
  #   6. Smoke test: sops -d <any encrypted file> (prompts for the PIV PIN).
  #
  # If the card ever seems dead to pcscd (LIBUSB_ERROR_BUSY in `journalctl -u
  # pcscd`, tools reporting "Failed to connect to YubiKey"), scdaemon has
  # seized the USB interface: `gpgconf --kill scdaemon` and replug. The
  # scdaemon.conf below prevents that, but only applies after a rebuild.
  #
  # TROUBLESHOOTING PLAYBOOK (everything below was learned the hard way,
  # 2026-07-09, when sops "broke" and turned out to be two stacked issues)
  #
  # Fast health check, no PIN needed — must print the .sops.yaml recipient:
  #   age-plugin-yubikey --list-all
  # It exits 0 and prints NOTHING both when no key is visible and when the
  # slot cert is rejected, so empty output is a symptom, not a diagnosis.
  # Work down the stack:
  #   1. ykman list                      — is the key even on USB?
  #   2. journalctl -u pcscd             — LIBUSB_ERROR_BUSY => scdaemon has
  #      the interface. Note pcscd does NOT retry a failed reader add: after
  #      freeing it (gpgconf --kill scdaemon) you must REPLUG the key (or
  #      restart pcscd) before the reader reappears.
  #   3. ykman piv info                  — is the cert still in slot 82?
  #   4. Does the slot key match the sops recipient? (no PIN needed):
  #        ykman piv certificates export 82 - | openssl x509 -pubkey -noout \
  #          | openssl ec -pubin -conv_form compressed -outform DER | tail -c 33 | xxd -p
  #      must equal the bech32-decoded age1yubikey1... recipient.
  #   5. Version differential — pin an old plugin straight from nixpkgs:
  #        nix run github:NixOS/nixpkgs/nixos-24.05#age-plugin-yubikey -- --list-all
  #      0.4.0 does not have the critical-extension check; if the old binary
  #      lists the key and the current one doesn't, it's the cert (see the
  #      import runbook above), not the card. This also works as a temporary
  #      PATH override to decrypt while the cert is still bad.
  #
  # Decoding "A YubiKey stub did not match the YubiKey": the plugin failed to
  # produce a (serial, slot, tag) match — it does NOT mean the key is wrong.
  # Observed causes: the slot cert was rejected (critical extension), or the
  # stub's serial wasn't visible (unplugged / scdaemon-held) while a different
  # YubiKey was.
  #
  # keys.txt anatomy (~/.config/sops/age/keys.txt):
  #   - AGE-PLUGIN-YUBIKEY-... = 9-byte bech32 stub: serial (4B little-endian)
  #     + slot byte (0x82) + tag (first 4B of sha256(compressed pubkey)).
  #     Slot key and tag are identical across cloned YubiKeys; only the serial
  #     differs — hence one stub line per card.
  #   - AGE-SECRET-KEY-...     = SOFTWARE identity used by the sops-nix unit
  #     for THIS repo's secrets.yaml. Home secrets decrypting fine proves
  #     nothing about the YubiKey path — different recipients entirely.
  #
  # Inspect a slot at the APDU level without any PIN (algorithm, PIN/touch
  # policy, generated-vs-imported origin, public key):
  #   opensc-tool -s "00:A4:04:00:05:A0:00:00:03:08" -s "00:F7:00:82:00"

  flake.modules.nixos.workstation =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      # Mirror the pcscd module's own package selection (a private let-binding
      # there, so it can't be read back off config): polkit build when polkit is
      # enabled, plain otherwise.
      pcscdPackage = if config.security.polkit.enable then pkgs.pcscliteWithPolkit else pkgs.pcsclite;
    in
    {
      services.pcscd = {
        enable = true;
        plugins = [ pkgs.ccid ];
      };

      # THE COLD-CARD FIX (2026-07-29). NixOS runs pcscd socket-activated with
      # --auto-exit (-x), so it quits after 60s of inactivity. Every ssh here is
      # authenticated by the YubiKey (the key lives on the card, fronted by
      # gpg-agent -> scdaemon -> pcscd in shared mode). When pcscd has exited, the
      # next connection must cold-start the entire card stack — systemd respawns
      # pcscd, it re-enumerates USB readers and powers up the card, then scdaemon
      # re-selects the applet before it can sign. That cold path costs ~4s at best
      # and 20-60s (sometimes failing outright) at worst, and since connections to
      # the fleet are spaced minutes apart it fired on nearly every call — the
      # "workstation hangs for a few seconds on ssh" symptom. Dropping --auto-exit
      # keeps pcscd resident so the card stays warm and signing stays sub-second.
      # /etc/reader.conf is the merged CCID config the pcscd module generates
      # (environment.etc."reader.conf"); keeping -c avoids the empty-config
      # network-reader probe the module documents.
      systemd.services.pcscd = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = lib.mkForce [
          ""
          "${pcscdPackage}/bin/pcscd -f -c /etc/reader.conf"
        ];
      };

      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };

      environment.systemPackages = with pkgs; [
        age-plugin-yubikey
        gnupg
        opensc
        yubico-piv-tool
        yubikey-manager
      ];
    };

  flake.modules.homeManager.base = { ... }: {
    # THE SCDAEMON FIX (2026-07-09). By default gpg's scdaemon talks to the
    # YubiKey through its OWN built-in CCID driver, claiming the USB interface
    # exclusively via libusb. pcscd then can't register the reader at all
    # (journalctl -u pcscd shows "Can't claim interface: LIBUSB_ERROR_BUSY" /
    # "YubiKey init failed"), and every PC/SC client silently loses the card:
    # sops decryption dies with misleading errors ("A YubiKey stub did not
    # match the YubiKey" — the stub was fine, the card was just invisible),
    # ykman/age-plugin-yubikey intermittently report "Failed to connect to
    # YubiKey" or list nothing, and which tool worked depended on whether
    # gpg-agent (SSH support) had poked the card first. This caused repeated,
    # hard-to-diagnose breakage before it was pinned down.
    #
    # disable-ccid makes scdaemon go through pcscd in SHARED mode like every
    # other client, so gpg SSH and sops/age coexist. If symptoms ever return
    # (e.g. before this file is active on a fresh install), the manual escape
    # hatch is: gpgconf --kill scdaemon, then replug the key.
    home.file.".gnupg/scdaemon.conf".text = ''
      disable-ccid
    '';
  };
}
