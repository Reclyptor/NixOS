{ config, pkgs, clusterDnsIP, ... }: {
  sops = {
    defaultSopsFile = ../../../secrets/secrets.yaml;
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
    secrets."k3s/token" = { };
  };

  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://127.0.0.1:6443";
    tokenFile = config.sops.secrets."k3s/token".path;
    extraFlags = [
      "--node-ip" "192.168.1.13"
      "--kubelet-arg=cluster-dns=${clusterDnsIP}"
    ];
  };

  networking.firewall = {
    allowedTCPPorts = [ 53 10250 3260 4240 4244 ];   # 53=node-local-dns TCP fallback
    allowedUDPPorts = [ 53 8472 51871 ];   # 53=node-local-dns, 8472=VXLAN, 51871=Cilium WireGuard
  };

  # Keep NetworkManager off Cilium's interfaces so it can't tear out the datapath
  # (root cause of prior dual-NIC failures). eno1/wlp2s0 stay NM-managed.
  networking.networkmanager.unmanaged = [ "interface-name:cilium_*" "interface-name:lxc*" ];
}
