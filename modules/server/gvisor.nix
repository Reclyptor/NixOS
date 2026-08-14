_: {
  flake.modules.nixos.server =
    { pkgs, ... }:
    let
      # containerd is 2.2 here, which reads config-v3.toml.tmpl.
      # `services.k3s.containerdConfigTemplate` still writes config.toml.tmpl,
      # and k3s only honours that as the legacy v2 fallback — using the option
      # would drop every node back to v2 config rendering and take the
      # auto-detected nvidia runtime with it. This is the same "L+" tmpfiles
      # link the upstream module uses, just at the path this containerd wants.
      containerdTemplate = pkgs.writeText "config-v3.toml.tmpl" ''
        {{ template "base" . }}

        [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.gvisor]
          runtime_type = 'io.containerd.runsc.v1'
      '';
    in
    {
      environment.systemPackages = [ pkgs.gvisor ];

      # runsc is not on k3s's runtime auto-detection list, so containerd resolves
      # it and containerd-shim-runsc-v1 off the unit PATH — the same way
      # nvidia-container-toolkit.tools is picked up in k3s.nix.
      systemd.services.k3s.path = [ pkgs.gvisor ];

      systemd.tmpfiles.settings."10-gvisor"."/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.tmpl"."L+".argument =
        "${containerdTemplate}";

      # k3s applies --node-label only at first registration, so the five existing
      # nodes need `kubectl label` by hand. Kept here so a rebuilt or replacement
      # node is schedulable for gVisor workloads with no manual step.
      services.k3s.nodeLabel = [ "gvisor.io/runsc=true" ];
    };
}
