{ config, pkgs, ... }: {
  programs.bash.shellAliases = {
    ls = "eza -a --icons=always";
    tree = "eza -a --tree --icons=always";
    
    mysql-reclyptor = "mysql -ureclyptor -p -h \${GCP_MYSQL_HOST} --ssl-ca=\${GCP_MYSQL_CA_CERT} --ssl-cert=\${GCP_MYSQL_CLIENT_CERT} --ssl-key=\${GCP_MYSQL_CLIENT_KEY}";
    mongo-reclyptor = "mongosh '\${ATLAS_MONGODB_HOST}' --apiVersion 1 --username reclyptor";
  };
}