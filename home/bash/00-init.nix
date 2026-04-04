{ config, pkgs, ... }: {
  programs.bash.initExtra = ''
    # PATH additions
    export PATH=$PATH:~/.local/bin/:~/.local/share/JetBrains/Toolbox/scripts

    if [ -f ~/.config/sops/secrets/bash/gcp-mysql-host ]; then
      export GCP_MYSQL_HOST=$(cat ~/.config/sops/secrets/bash/gcp-mysql-host)
    fi

    if [ -f ~/.config/sops/secrets/bash/k3s-host ]; then
      export K3S_HOST=$(cat ~/.config/sops/secrets/bash/k3s-host)
    fi
    if [ -f ~/.config/sops/secrets/bash/k3s-mysql-password ]; then
      export K3S_MYSQL_PASSWORD=$(cat ~/.config/sops/secrets/bash/k3s-mysql-password)
    fi
    if [ -f ~/.config/sops/secrets/bash/k3s-mongodb-password ]; then
      export K3S_MONGODB_PASSWORD=$(cat ~/.config/sops/secrets/bash/k3s-mongodb-password)
    fi

    # Google Cloud SQL certificates (managed by sops-nix)
    if [ -f ~/.config/sops/secrets/bash/gcp-mysql-ca-cert ]; then
      export GCP_MYSQL_CA_CERT=~/.config/sops/secrets/bash/gcp-mysql-ca-cert
    fi
    if [ -f ~/.config/sops/secrets/bash/gcp-mysql-client-cert ]; then
      export GCP_MYSQL_CLIENT_CERT=~/.config/sops/secrets/bash/gcp-mysql-client-cert
    fi
    if [ -f ~/.config/sops/secrets/bash/gcp-mysql-client-key ]; then
      export GCP_MYSQL_CLIENT_KEY=~/.config/sops/secrets/bash/gcp-mysql-client-key
    fi

    if [ -f ~/.config/sops/secrets/bash/k3s-redis-password ]; then
      export K3S_REDIS_PASSWORD=$(cat ~/.config/sops/secrets/bash/k3s-redis-password)
    fi

    if [ -f ~/.config/sops/secrets/bash/atlas-mongodb-host ]; then
      export ATLAS_MONGODB_HOST=$(cat ~/.config/sops/secrets/bash/atlas-mongodb-host)
    fi
  '';
}