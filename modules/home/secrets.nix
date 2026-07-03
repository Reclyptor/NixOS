{ ... }: {
  flake.modules.homeManager.base = { config, pkgs, lib, ... }: {
    sops = {
      defaultSopsFile = ../../secrets/secrets.yaml;

      age = {
        keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
        sshKeyPaths = [];
        # Decryption runs inside the sops-nix user unit; plugins listed here
        # end up on that unit's PATH (identities live on the YubiKey).
        plugins = [ pkgs.age-plugin-yubikey ];
      };

      # Each secret decrypts to ~/.config/sops/secrets/<name>.
      secrets = lib.genAttrs [
        "bash/gcp-mysql-host"
        "bash/gcp-mysql-ca-cert"
        "bash/gcp-mysql-client-cert"
        "bash/gcp-mysql-client-key"
        "bash/k3s-host"
        "bash/k3s-mysql-password"
        "bash/k3s-mongodb-password"
        "bash/atlas-mongodb-host"
        "bash/k3s-redis-password"
        "agentmemory/claude-token"
        "agentmemory/qwen-token"
      ] (name: {
        path = "${config.home.homeDirectory}/.config/sops/secrets/${name}";
      });
    };
  };
}
