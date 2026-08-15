_: {
  flake.modules.homeManager.base =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      ageKeyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    in
    {
      # keys.txt holds the software age identity that decrypts secrets/secrets.yaml
      # (plus the YubiKey stub for the kubernetes repo). A private key can't be
      # committed to the repo it decrypts, so the file itself is provisioned out of
      # band — but its MODE can be enforced declaratively, and must be: it shipped
      # 0644, which left every credential in secrets.yaml readable by any local
      # process. Runs on every activation so it can't silently drift back.
      home.activation.ageKeyPermissions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -f ${lib.escapeShellArg ageKeyFile} ]; then
          $DRY_RUN_CMD chmod 0600 ${lib.escapeShellArg ageKeyFile}
        fi
      '';

      sops = {
        defaultSopsFile = ../../secrets/secrets.yaml;

        age = {
          keyFile = ageKeyFile;
          sshKeyPaths = [ ];
          # Decryption runs inside the sops-nix user unit; plugins listed here
          # end up on that unit's PATH (identities live on the YubiKey).
          plugins = [ pkgs.age-plugin-yubikey ];
        };

        # Each secret decrypts to ~/.config/sops/secrets/<name>.
        secrets =
          lib.genAttrs
            [
              "bash/gcp-mysql-host"
              "bash/gcp-mysql-ca-cert"
              "bash/gcp-mysql-client-cert"
              "bash/gcp-mysql-client-key"
              "bash/k3s-host"
              "bash/k3s-mysql-password"
              "bash/k3s-mongodb-password"
              "bash/atlas-mongodb-host"
              "bash/k3s-redis-password"
              "bash/steam-web-api-key"
              "bash/github-token"
              "agentmemory/claude-token"
              "agentmemory/qwen-token"
            ]
            (name: {
              path = "${config.home.homeDirectory}/.config/sops/secrets/${name}";
            });
      };
    };
}
