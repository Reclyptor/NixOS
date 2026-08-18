_: {
  flake.modules.homeManager.base =
    { lib, ... }:
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
        # gh reads GH_TOKEN first and falls back to GITHUB_TOKEN, so this one name
        # covers the gh CLI (which is how Claude Code and Codex reach GitHub) as
        # well as the tooling that only knows GITHUB_TOKEN. It overrides the token
        # stored in ~/.config/gh/hosts.yml — deliberate, and not a downgrade: this
        # PAT is scoped wider than the gh OAuth token it shadows.
        GITHUB_TOKEN = "github-token";
        # Scoped token for the Makotogotchi zones (Tunnel/DNS/Cache/WAF Edit);
        # consumed by Makotogotchi's scripts/cloudflare-setup.sh.
        CLOUDFLARE_API_TOKEN = "cloudflare-token";
        # Cloudflare Access service token guarding the vLLM endpoint. This is a
        # different credential from CLOUDFLARE_API_TOKEN above: that one manages
        # zones, this pair authenticates THROUGH Access to a tunnelled origin.
        CF_ACCESS_CLIENT_ID = "cf-access-client-id";
        CF_ACCESS_CLIENT_SECRET = "cf-access-client-secret";
        # Deliberately not DEEPSEEK_BASE_URL: pi-ai does ambient environment
        # discovery for its built-in providers, so a DEEPSEEK_-prefixed variable
        # risks repointing the official route instead of only the custom one.
        VLLM_BASE_URL = "vllm-base-url";
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
      mkExports =
        toValue:
        lib.mapAttrsToList (
          name: file:
          ''if [ -f "${secretsDir}/${file}" ]; then export ${name}="${toValue "${secretsDir}/${file}"}"; fi''
        );

      exports = lib.concatStringsSep "\n" (
        mkExports (path: ''$(cat "${path}")'') valueExports ++ mkExports (path: path) pathExports
      );
    in
    {
      programs.bash.initExtra = ''
        # PATH additions
        export PATH=$PATH:~/.local/bin/:~/.local/share/JetBrains/Toolbox/scripts

        # Secrets decrypted by sops-nix, exported when present
        ${exports}
      '';
    };
}
