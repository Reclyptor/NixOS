{ config, lib, pkgs, ... }:
let
  # Your WireGuard connection names. Each name here must match a key you add
  # under `wireguard:` in secrets/secrets.yaml (see the block below), and it
  # becomes the NetworkManager connection id + interface name (max 15 chars,
  # no spaces). Edit this list to match the .conf files you actually have.
  connections = [ "home" ];

  secretName = name: "wireguard/${name}";
in {
  sops = {
    defaultSopsFile = ../../../secrets/secrets.yaml;

    # Private key backing the &nixos recipient already in .sops.yaml. These are
    # the two conventional locations and sops-nix uses whichever one decrypts.
    # If this host's key lives somewhere else, change these two lines only.
    age = {
      sshKeyPaths = [];
      keyFile = "/home/reclyptor/.config/sops/age/keys.txt";
    };

    # Each secret is the full .conf, decrypted to /run/secrets/wireguard/<name>
    # as root-only (0400). Nothing lands in the world-readable Nix store.
    secrets = lib.listToAttrs (map (name: {
      name = secretName name;
      value.path = "/run/secrets/wireguard/${name}.conf";
    }) connections);
  };

  environment.systemPackages = [ pkgs.wireguard-tools ];

  # NetworkManager imports each decrypted .conf on boot if it isn't already a
  # known connection. After import the profile lives in NM's root-only store
  # and toggles from the applet or `nmcli connection up <name>`. To refresh a
  # changed config: `nmcli connection delete <name>` then rebuild.
  systemd.services.wireguard-nm-import = {
    description = "Import sops-provided WireGuard configs into NetworkManager";
    after = [ "NetworkManager.service" "sops-nix.service" ];
    wants = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.networkmanager pkgs.gnugrep ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = lib.concatMapStringsSep "\n" (name: ''
      if nmcli -t -f NAME connection show | grep -qx "${name}"; then
        echo "wireguard: connection '${name}' already present, skipping"
      else
        echo "wireguard: importing connection '${name}'"
        nmcli connection import type wireguard file ${config.sops.secrets.${secretName name}.path}
      fi
    '') connections;
  };
}
