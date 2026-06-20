{ ... }:

{
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
        server archeon 192.168.1.10:6443 check
        server fluxeon 192.168.1.11:6443 check
        server voideon 192.168.1.12:6443 check
    '';
  };

  # Workstation-only Kubernetes API endpoint for kubectl/helm/flux.
  # Keep this local to the workstation config; cluster nodes have their own
  # per-host load balancers under hosts/<node>/modules/kube-api-lb.nix.
  systemd.services.haproxy = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
