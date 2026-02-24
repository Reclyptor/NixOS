{ pkgs, ... }: {
  hardware.i2c.enable = true;

  services.hardware.openrgb = {
    enable = true;
    motherboard = "intel";
    package = pkgs.openrgb;
  };

  environment.systemPackages = with pkgs; [
    openrgb
  ];
}
