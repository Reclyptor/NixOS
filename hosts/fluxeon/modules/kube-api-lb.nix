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

  # Local pre-CNI Kubernetes API endpoint for k3s agents and Cilium.
  # Server nodes bind their real apiserver to the LAN IP so HAProxy can own
  # 127.0.0.1:6443 without colliding with kube-apiserver on port 6443.
  systemd.services.haproxy = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = "5s";
    };
  };

  systemd.services.k3s = {
    after = [ "haproxy.service" ];
    requires = [ "haproxy.service" ];
  };
}
