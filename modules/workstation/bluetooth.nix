_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [ blueman ];
    services.blueman.enable = true;
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
