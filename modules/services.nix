{ config, pkgs, ... }: {
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
  };

  services.blueman.enable = true;
}
