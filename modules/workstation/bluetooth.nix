_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [ blueman ];
    services.blueman.enable = true;
    # powerOnBoot is the module default (true) — declared explicitly it only
    # drifts if the default ever changes, so the option is left unset.
    hardware.bluetooth.enable = true;
  };
}
