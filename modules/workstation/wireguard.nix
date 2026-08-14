{ ... }: {
  flake.modules.nixos.workstation =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Your WireGuard connection names. Each name here must match a key you add
      # under `wireguard:` in secrets/secrets.yaml (see the block below), and it
      # becomes the NetworkManager connection id + interface name (max 15 chars,
      # no spaces). Edit this list to match the .conf files you actually have.
      connections = [ "home" ];

      secretName = name: "wireguard/${name}";
    in
    {
      # The sops key source and defaultSopsFile live in workstation/sops.nix.
      # Each secret is the full .conf, decrypted to /run/secrets/wireguard/<name>
      # as root-only (0400). Nothing lands in the world-readable Nix store.
      sops.secrets = lib.listToAttrs (
        map (name: {
          name = secretName name;
          value.path = "/run/secrets/wireguard/${name}.conf";
        }) connections
      );

      environment.systemPackages = [ pkgs.wireguard-tools ];

      # NetworkManager imports each decrypted .conf on boot if it isn't already a
      # known connection. These tunnels are strictly manual: autoconnect is forced
      # off on every run, including for profiles that already exist, so a tunnel
      # only ever comes up when you bring it up from the applet or with
      # `nmcli connection up <name>`. To refresh a changed config:
      # `nmcli connection delete <name>` then rebuild.
      systemd.services.wireguard-nm-import = {
        description = "Import sops-provided WireGuard configs into NetworkManager";
        after = [
          "NetworkManager.service"
          "sops-nix.service"
        ];
        wants = [ "NetworkManager.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.networkmanager
          pkgs.gnugrep
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = lib.concatMapStringsSep "\n" (name: ''
          if nmcli -t -f NAME connection show | grep -qx "${name}"; then
            echo "wireguard: connection '${name}' already present, skipping import"
          else
            echo "wireguard: importing connection '${name}'"
            nmcli connection import type wireguard file ${config.sops.secrets.${secretName name}.path}
          fi
          nmcli connection modify "${name}" connection.autoconnect no connection.autoconnect-priority 0
          # `nmcli connection import` activates the tunnel as a side effect, so tear
          # it back down; this is a no-op when the tunnel was already inactive.
          nmcli connection down "${name}" >/dev/null 2>&1 || true
        '') connections;
      };
    };
}
