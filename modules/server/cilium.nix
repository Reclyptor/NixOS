{ config, lib, ... }:
let
  # Distinct wired NICs across the whole fleet, in lexicographic node order —
  # which reproduces the previously hand-written "eno1 enp6s0" exactly.
  #
  # The union spans ALL nodes, not just the servers that render this manifest:
  # k3s auto-deploy applies it cluster-wide, so the agents' NICs must appear here
  # too. Kept as a Nix comment rather than a YAML one on purpose — the values
  # file feeds `helm template`, whose output embeds freshly generated Hubble TLS
  # certificates, so ANY edit to that string (comments included) re-renders the
  # manifest and rolls those certs on the cluster.
  wiredDevices = lib.concatStringsSep " " (
    lib.unique (lib.mapAttrsToList (_: node: node.wiredInterface) config.fleet.nodes)
  );
in
{
  flake.modules.nixos.server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Pinned to Cilium 1.20.4, whose e2e-tested Kubernetes range is 1.33–1.36;
      # the cluster runs k3s 1.36 (pinned to the minor in k3s.nix). The pin is
      # intentional — the CNI must not silently auto-update. Bump the version and
      # hash together, one minor at a time, and check the new release's
      # compatibility page covers the k3s minor before switching.
      version = "1.20.4";

      chart = pkgs.fetchurl {
        url = "https://helm.cilium.io/cilium-${version}.tgz";
        hash = "sha256-UFq/+DhYEd8alJd2/ELp8QaXmJozKsyG1uiTPvy4Ve0=";
      };

      values = pkgs.writeText "cilium-values.yaml" ''
        kubeProxyReplacement: true
        k8sServiceHost: "127.0.0.1"      # node-local HAProxy fanout to archeon/fluxeon/voideon apiservers; available before CNI
        k8sServicePort: 6443

        routingMode: native              # all 5 nodes share one L2 (192.168.1.0/24), so
        autoDirectNodeRoutes: true       # each installs direct routes to peer pod CIDRs —
                                         # no encap. VXLAN was needless overhead here, and
                                         # its double-encap broke WireGuard's MTU.
        ipv4NativeRoutingCIDR: "10.42.0.0/16"   # pod CIDR routed natively (not masqueraded)

        # Both were set on the live cluster by a kubectl patch on 2026-06-20 and
        # are declared here at their live values so the rendered ConfigMap owns
        # them. Per-endpoint routes send pod traffic straight to each lxc device
        # instead of through cilium_host; audit mode off means policies enforce.
        endpointRoutes:
          enabled: true
        policyAuditMode: false

        # WIRED ONLY (validated): eno1 on archeon/fluxeon/voideon/styxeon, enp6s0 on
        # bytheon. Never wlp2s0/wlo1 (wireless = OOB SSH lifeline).
        devices: "${wiredDevices}"

        ipam:
          mode: cluster-pool
          operator:
            clusterPoolIPv4PodCIDRList:
              - "10.42.0.0/16"           # matches k3s default --cluster-cidr
            clusterPoolIPv4MaskSize: 24

        l2announcements:
          enabled: true
          # Chart defaults are 15s/5s/2s. On a node reboot every Service whose L2
          # lease sat on that node blackholes until the lease expires; this halves
          # that window. Invariant: leaseDuration > leaseRenewDeadline > leaseRetryPeriod.
          # k8sClientRateLimit below was already raised for lease churn.
          leaseDuration: 7s
          leaseRenewDeadline: 3s
          leaseRetryPeriod: 1s
        externalIPs:
          enabled: true

        k8sClientRateLimit:              # L2 lease churn hits the API; raise limits
          qps: 50
          burst: 200

        bpf:
          # eBPF masquerade is REQUIRED with the BPF kube-proxy replacement. Running
          # iptables masquerade here collides with the BPF NodePort SNAT and DROPS
          # cross-node LoadBalancer connections (only the announcing node's local
          # backends answer). `false` was a misdiagnosis: the pod->node-IP/CoreDNS
          # crashloop that prompted it was the dual-NIC priority-100 routing collision
          # (fixed in network.nix), not masquerade. Verified live 2026-06-18 — `true`
          # keeps CoreDNS healthy AND makes remote-backend LB VIPs reachable.
          masquerade: true

        # Transparent WireGuard encryption of pod-to-pod traffic between nodes. Works
        # on native routing (single encap); the VXLAN-tunnel double-encap broke its MTU.
        # Verified live 2026-06-18. WireGuard uses UDP 51871 (open in k3s.nix firewall).
        encryption:
          enabled: true
          type: wireguard

        # Metrics for the monitoring stack (kubernetes repo, SPEC/monitoring-stack.md).
        # These only open the endpoints; the scrape definitions live in the Flux
        # repo. All three run in the host network namespace, so k3s.nix opens the
        # matching ports in the node firewall — without that a scrape from a pod on
        # another node is dropped at the destination's nftables.
        prometheus:
          enabled: true                  # cilium-agent :9962 — cilium_drop_count_total lives here

        # Requests only, sized from 30 days of observed usage (2026-11-13);
        # no limits, since an OOM-killed CNI component takes networking with it.
        envoy:
          resources:
            requests:
              cpu: 10m
              memory: 64Mi

        operator:
          replicas: 2                    # 3 servers available
          prometheus:
            enabled: true                # cilium-operator :9963
          resources:
            requests:
              cpu: 25m
              memory: 128Mi

        hubble:
          enabled: true
          # :9965. Namespace-level context. `flow` and `port-distribution` are left
          # out for cardinality; `httpV2` because it needs L7 policy (Envoy).
          metrics:
            enabled: [dns, drop, tcp]
          relay:
            enabled: true
            resources:
              requests:
                cpu: 10m
                memory: 64Mi
          ui:
            enabled: true
            service:
              # Hubble UI has no built-in auth, so keep it off the LAN.
              # Reach it with `cilium hubble ui` or a kubectl port-forward.
              type: ClusterIP
            backend:
              resources:
                requests:
                  cpu: 5m
                  memory: 64Mi
            frontend:
              resources:
                requests:
                  cpu: 5m
                  memory: 32Mi

      '';

      manifest =
        pkgs.runCommand "cilium-${version}-manifest.yaml" { nativeBuildInputs = [ pkgs.kubernetes-helm ]; }
          ''
            export HOME="$TMPDIR"
            helm template cilium ${chart} \
              --namespace kube-system \
              --values ${values} \
              > "$out"
          '';
    in
    lib.mkIf (config.host.k3s.role == "server") {
      # Cilium CNI is bootstrapped via k3s auto-deploy (server nodes only) so the
      # cluster network is up before Flux — avoids the GitOps deadlock. The manifest
      # is rendered at build time from the pinned chart + values above (no vendored
      # YAML). Operational config (LB-IPAM pools, L2 policies, network policies)
      # lives in the Flux repo under core/cilium/, not here.
      services.k3s.manifests.cilium = {
        target = "cilium.yaml";
        source = manifest;
      };
    };
}
