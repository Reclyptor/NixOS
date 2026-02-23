{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    pavucontrol
    playerctl
  ];
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
  };
}
