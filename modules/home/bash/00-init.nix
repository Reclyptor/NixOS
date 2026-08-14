{ ... }: {
  flake.modules.homeManager.base = { lib, ... }:
    let
      # $HOME, not ~: the paths below are quoted, and tilde expansion does not
      # happen inside double quotes (it would leave a literal "~/..." that no
      # client can open). $HOME expands in both quoted and unquoted contexts.
      secretsDir = "$HOME/.config/sops/secrets/bash";

      # Secrets whose decrypted CONTENT becomes the variable value.
      valueExports = {
        GCP_MYSQL_HOST = "gcp-mysql-host";
        K3S_HOST = "k3s-host";
        K3S_MYSQL_PASSWORD = "k3s-mysql-password";
        K3S_MONGODB_PASSWORD = "k3s-mongodb-password";
        K3S_REDIS_PASSWORD = "k3s-redis-password";
        ATLAS_MONGODB_HOST = "atlas-mongodb-host";
        STEAM_WEB_API_KEY = "steam-web-api-key";
      };

      # Secrets whose PATH becomes the variable value (certs read on use).
      pathExports = {
        GCP_MYSQL_CA_CERT = "gcp-mysql-ca-cert";
        GCP_MYSQL_CLIENT_CERT = "gcp-mysql-client-cert";
        GCP_MYSQL_CLIENT_KEY = "gcp-mysql-client-key";
      };

      # The value is quoted: an unquoted $(cat …) undergoes word splitting and
      # globbing, so a secret containing whitespace or a glob character would be
      # silently mangled at shell startup.
      mkExports = toValue: lib.mapAttrsToList (name: file:
        ''if [ -f "${secretsDir}/${file}" ]; then export ${name}="${toValue "${secretsDir}/${file}"}"; fi''
      );

      exports = lib.concatStringsSep "\n"
        (mkExports (path: ''$(cat "${path}")'') valueExports
          ++ mkExports (path: path) pathExports);
    in {
      programs.bash.initExtra = ''
        # PATH additions
        export PATH=$PATH:~/.local/bin/:~/.local/share/JetBrains/Toolbox/scripts

        # Secrets decrypted by sops-nix, exported when present
        ${exports}
      '';
    };
}
