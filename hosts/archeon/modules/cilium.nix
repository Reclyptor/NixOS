{ pkgs, ... }:

let
  # Pinned to Cilium 1.19.5 (supports k8s 1.32–1.35; cluster is k3s v1.35.2).
  # The pin is intentional — the CNI must not silently auto-update. Bump the
  # version and hash together to upgrade. Keep identical on all server nodes
  # (archeon/fluxeon/voideon).
  chart = pkgs.fetchurl {
    url = "https://helm.cilium.io/cilium-1.19.5.tgz";
    hash = "sha256-VrYERaLGULOHzi7bE8/Y2DIZqdppOwUjkV26i+RRop4=";
  };

  values = pkgs.writeText "cilium-values.yaml" ''
    kubeProxyReplacement: true
    k8sServiceHost: "192.168.1.10"   # archeon apiserver (= agents' serverAddr); reachable from all nodes. 127.0.0.1 only resolves on servers. TODO: VIP/agent-LB for CNI HA
    k8sServicePort: 6443

    routingMode: tunnel              # VXLAN (UDP 8472, already open in firewall)
    tunnelProtocol: vxlan

    # WIRED ONLY (validated): eno1 on archeon/fluxeon/voideon/styxeon, enp6s0 on
    # bytheon. Never wlp2s0/wlo1 (wireless = OOB SSH lifeline).
    devices: "eno1 enp6s0"

    ipam:
      mode: cluster-pool
      operator:
        clusterPoolIPv4PodCIDRList:
          - "10.42.0.0/16"           # matches k3s default --cluster-cidr
        clusterPoolIPv4MaskSize: 24

    l2announcements:
      enabled: true
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

    operator:
      replicas: 2                    # 3 servers available

    hubble:
      enabled: true
      relay:
        enabled: true
      ui:
        enabled: true
  '';

  manifest = pkgs.runCommand "cilium-1.19.5-manifest.yaml"
    { nativeBuildInputs = [ pkgs.kubernetes-helm ]; }
    ''
      export HOME="$TMPDIR"
      helm template cilium ${chart} \
        --namespace kube-system \
        --values ${values} \
        > "$out"
    '';
in
{
  # Cilium CNI is bootstrapped via k3s auto-deploy (server nodes only) so the
  # cluster network is up before Flux — avoids the GitOps deadlock. The manifest
  # is rendered at build time from the pinned chart + values above (no vendored
  # YAML). Operational config (LB-IPAM pools, L2 policies, network policies)
  # lives in the Flux repo under core/cilium/, not here.
  services.k3s.manifests.cilium = {
    target = "cilium.yaml";
    source = manifest;
  };
}
