_: {
  flake.modules.nixos.workstation = _: {
    # scx_lavd scores tasks by latency criticality from their sleep/wake
    # pattern, so cadence-driven threads (a game's renderer) keep the P-cores
    # while CPU-bound batch work settles onto the E-cores. It reads the hybrid
    # topology itself rather than us hand-encoding the split.
    services.scx = {
      enable = true;
      scheduler = "scx_lavd";
    };
  };
}
