{ config, lib, ... }:

# Local pre-CNI Kubernetes API endpoint, shared by every machine:
#  - cluster nodes reach the apiservers through it before the CNI is up
#    (k3s is ordered after it in server/k3s.nix);
#  - the workstation uses it as the kubectl/helm/flux endpoint.
# Server nodes bind their real apiserver to the LAN IP so HAProxy can own
# 127.0.0.1:6443 without colliding with kube-apiserver on port 6443.
let
  # Backends come from the fleet inventory's control-plane set, so promoting a
  # node to server role updates this automatically. Attribute order is
  # lexicographic, which is what the hand-written list already was.
  #
  # Two leading spaces, not the source indentation below: Nix strips the block's
  # common indent (8) from literal lines only, so interpolated text arrives at
  # column 0 and has to carry the final indentation itself.
  backends = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: node: "  server ${name} ${node.wiredIp}:6443 check"
    ) config.fleet.controlPlane
  );

  haproxy = {
    services.haproxy = {
      enable = true;
      config = ''
        global
          log stdout format raw local0
          maxconn 2048

        defaults
          mode tcp
          log global
          option tcplog
          timeout connect 5s
          timeout client 1m
          timeout server 1m

        frontend kube_api
          bind 127.0.0.1:6443
          default_backend kube_api_servers

        backend kube_api_servers
          balance roundrobin
          option tcp-check
          default-server inter 2s fall 3 rise 2
        ${backends}
      '';
    };

    systemd.services.haproxy = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };
in
{
  flake.modules.nixos.server = haproxy;
  flake.modules.nixos.workstation = haproxy;
}
