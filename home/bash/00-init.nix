{ config, pkgs, ... }: {
  programs.bash.sessionVariables = {
    # Google Cloud SQL 
    GCP_MYSQL_CA_CERT = "/etc/ssl/cloudsql/server-ca.pem";
    GCP_MYSQL_CLIENT_CERT = "/etc/ssl/cloudsql/client-cert.pem";
    GCP_MYSQL_CLIENT_KEY = "/etc/ssl/cloudsql/client-key.pem";
  };
  
  programs.bash.initExtra = ''
    # PATH additions
    export PATH=$PATH:~/.local/bin/:~/.local/share/JetBrains/Toolbox/scripts
    
    if [ -f ~/.config/sops/secrets/bash/gcp-mysql-host ]; then
      export GCP_MYSQL_HOST=$(cat ~/.config/sops/secrets/bash/gcp-mysql-host)
    fi

    if [ -f ~/.config/sops/secrets/bash/atlas-mongodb-host ]; then
      export ATLAS_MONGODB_HOST=$(cat ~/.config/sops/secrets/bash/atlas-mongodb-host)
    fi
  '';
}