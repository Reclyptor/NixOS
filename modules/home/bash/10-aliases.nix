_: {
  flake.modules.homeManager.base = _: {
    programs.bash.shellAliases = {
      ls = "eza -a --icons=always";
      tree = "eza -a --tree --icons=always";

      claudex = "claude --dangerously-skip-permissions";
      codexx = "codex --dangerously-bypass-approvals-and-sandbox";

      # Passwords go through the environment, never argv. /proc/<pid>/cmdline is
      # world-readable (no hidepid), so `mysql -pSECRET` and `redis-cli -a SECRET`
      # exposed these to every local user for as long as the client ran;
      # /proc/<pid>/environ is same-uid-only, which is the boundary these
      # credentials already live behind anyway. Both variables are the vendors'
      # own documented alternative to the flag.
      mysql-reclyptor = "mysql -u$USER -p -h \${GCP_MYSQL_HOST} --ssl-ca=\${GCP_MYSQL_CA_CERT} --ssl-cert=\${GCP_MYSQL_CLIENT_CERT} --ssl-key=\${GCP_MYSQL_CLIENT_KEY}";
      mysql-k3s = "MYSQL_PWD=\${K3S_MYSQL_PASSWORD} mysql -u$USER -h \${K3S_HOST}";
      mongo-reclyptor = "mongosh '\${ATLAS_MONGODB_HOST}' --apiVersion 1 --username $USER";
      # mongosh has no password environment variable, so this one still passes it
      # in argv. Dropping the value from --password would make it prompt instead.
      mongo-k3s = "mongosh --host \${K3S_HOST} --username $USER --password \${K3S_MONGODB_PASSWORD}";
      redis-k3s = "REDISCLI_AUTH=\${K3S_REDIS_PASSWORD} redis-cli -h \${K3S_HOST}";
    };
  };
}
