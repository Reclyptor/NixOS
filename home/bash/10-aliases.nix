{ config, pkgs, ... }: {
  programs.bash.shellAliases = {
    ls = "eza -a --icons=always";
    tree = "eza -a --tree --icons=always";
    
    mysql-reclyptor = "mysql -u$USER -p -h \${GCP_MYSQL_HOST} --ssl-ca=\${GCP_MYSQL_CA_CERT} --ssl-cert=\${GCP_MYSQL_CLIENT_CERT} --ssl-key=\${GCP_MYSQL_CLIENT_KEY}";
    mysql-k3s = "mysql -u$USER -p\${K3S_MYSQL_PASSWORD} -h \${K3S_HOST}";
    mongo-reclyptor = "mongosh '\${ATLAS_MONGODB_HOST}' --apiVersion 1 --username $USER";
    mongo-k3s = "mongosh --host \${K3S_HOST} --username $USER --password \${K3S_MONGODB_PASSWORD}";
  };
}