_: {
  flake.modules.nixos.server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Workaround for Cilium DNS proxy + WireGuard incompatibility:
      # https://github.com/cilium/cilium/issues/45837
      #
      # Pods use node-local-dns so Cilium's L7 DNS proxy forwards upstream queries
      # to a same-node hostNetwork resolver instead of sending proxy-originated DNS
      # traffic across WireGuard to a remote CoreDNS pod. If Cilium fixes host-netns
      # DNS proxy reply handling over WireGuard, this can be reverted to kube-dns
      # (10.43.0.10) and the node-local-dns/firewall workaround can be removed.
      clusterDnsIP = "169.254.20.10";
      isServer = config.host.k3s.role == "server";
      nodeIp = config.host.wiredIp;

      # Control-plane peers, the only hosts that ever speak to etcd (2379 client,
      # 2380 peer). Agents never do. These same three addresses are also spelled
      # out in base.nix's networking.hosts and kube-api-lb.nix's HAProxy backends;
      # collapsing all of them into one fleet definition is deferred (see SPEC.md).
      controlPlaneIps = [
        "192.168.1.10" # archeon
        "192.168.1.11" # fluxeon
        "192.168.1.12" # voideon
      ];
      etcdPorts = "2379:2380";

      etcdRule =
        op: ip: "iptables -${op} nixos-fw -p tcp -s ${ip} --dport ${etcdPorts} -j nixos-fw-accept";
    in
    {
      sops = {
        defaultSopsFile = ../../secrets/secrets.yaml;
        age = {
          sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        };
        secrets."k3s/token" = { };
      };

      # k3s must not start before the local API load balancer (kube-api-lb.nix)
      # owns 127.0.0.1:6443 — both servers joining via it and agents need it up.
      systemd.services.k3s = {
        after = [ "haproxy.service" ];
        requires = [ "haproxy.service" ];
        path = lib.mkIf (config.host.gpu == "nvidia") [ pkgs.nvidia-container-toolkit.tools ];
      };

      services.k3s = {
        enable = true;
        role = config.host.k3s.role;
        clusterInit = lib.mkIf config.host.k3s.bootstrap true;
        serverAddr = lib.mkIf (!config.host.k3s.bootstrap) "https://127.0.0.1:6443";
        tokenFile = config.sops.secrets."k3s/token".path;
        extraFlags =
          if isServer then
            [
              "--node-ip"
              nodeIp
              "--bind-address=${nodeIp}"
              "--advertise-address=${nodeIp}"
              "--tls-san=127.0.0.1"
              "--flannel-backend=none"
              "--disable-network-policy"
              "--disable-kube-proxy"
              "--egress-selector-mode=cluster"
              "--disable=servicelb"
              "--disable=traefik"
              "--kubelet-arg=cluster-dns=${clusterDnsIP}"
            ]
          else
            (
              [
                "--node-ip"
                nodeIp
              ]
              ++ lib.optionals (config.host.gpu == "nvidia") [
                "--node-label=nvidia.com/gpu.present=true"
                "--node-label=node.kubernetes.io/gpu=true"
              ]
              ++ [
                "--kubelet-arg=cluster-dns=${clusterDnsIP}"
              ]
            );
      };

      # 53 and 10250 stay open to everything on purpose. 53 is node-local-dns,
      # which pods reach at 169.254.20.10 — traffic that never arrives on the
      # wired NIC — and 10250 is kubelet, scraped from in-cluster Prometheus over
      # the pod network via cilium_host. Narrowing either to the LAN interface
      # would silently drop legitimate traffic.
      networking.firewall = {
        allowedTCPPorts =
          if isServer then
            [
              53
              6443
              9345
              10250
              3260
              4240
              4244
            ] # 53=node-local-dns TCP fallback; etcd handled below
          else
            [
              53
              10250
              3260
              4240
              4244
            ]; # agents expose no apiserver/etcd
        allowedUDPPorts = [
          53
          8472
          51871
        ]; # 53=node-local-dns, 8472=VXLAN, 51871=Cilium WireGuard

        # etcd (2379/2380) is deliberately absent from allowedTCPPorts above: a
        # reachable etcd is total cluster compromise — the join token, every
        # Secret, and arbitrary writes to any object. It was open to the whole
        # 192.168.1.0/24. Only the other control-plane nodes need it.
        #
        # -I inserts at the head of nixos-fw so these accepts precede the chain's
        # closing refuse; every other source falls through to that refuse exactly
        # as it would for any unopened port. iptables, not nftables: switching
        # the firewall backend under Cilium's BPF kube-proxy replacement is the
        # class of change that has broken this cluster's datapath before.
        extraCommands = lib.optionalString isServer (
          lib.concatMapStringsSep "\n" (etcdRule "I") controlPlaneIps
        );

        # Mandatory counterpart — without it the manual rules survive a
        # firewall.service restart and accumulate a duplicate set each time.
        extraStopCommands = lib.optionalString isServer (
          lib.concatMapStringsSep "\n" (ip: "${etcdRule "D" ip} 2>/dev/null || true") controlPlaneIps
        );
      };

      # Keep NetworkManager off Cilium's interfaces so it can't tear out the datapath
      # (root cause of prior dual-NIC failures). The wired/wireless NICs stay NM-managed.
      networking.networkmanager.unmanaged = [
        "interface-name:cilium_*"
        "interface-name:lxc*"
      ];
    };
}
