_: {
  flake.modules.homeManager.base = { config, ... }: {
    # Only the env file is managed here; the toolchain itself comes from
    # workstation/devtools.nix. The env file rather than a session variable
    # because `go` reads it on every run, so editors, user units and agent
    # shells that never source .bashrc all agree on GOPATH.
    programs.go = {
      enable = true;
      package = null;
      env.GOPATH = "${config.xdg.dataHome}/go";
    };
  };
}
