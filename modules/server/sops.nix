_: {
  # System-level sops root of trust for the cluster nodes, mirroring
  # workstation/sops.nix. This was declared inside k3s.nix, so a module about
  # the Kubernetes distribution silently owned a host-wide security setting.
  #
  # Unlike the workstation, these hosts run sshd, so the host key is present and
  # sops-nix can derive the age identity from it directly — no key file to
  # provision, nothing to keep in sync.
  flake.modules.nixos.server = _: {
    sops = {
      defaultSopsFile = ../../secrets/secrets.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
  };
}
