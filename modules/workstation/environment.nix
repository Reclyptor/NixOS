_: {
  flake.modules.nixos.workstation = _: {
    environment.sessionVariables = {
      EDITOR = "nvim";
      BROWSER = "zen-beta";
      # A command name, not a store path. Interpolating the package pinned a
      # specific store path into every session's environment, so the value
      # churned on each rebuild and live sessions kept pointing at a superseded
      # (and eventually garbage-collected) path.
      DEFAULT_BROWSER = "zen-beta";
    };
  };
}
