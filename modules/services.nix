{ config, pkgs, ... }: {
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --cmd ${pkgs.hyprland}/bin/Hyprland";
        user = "reclyptor";
      };
    };
  };

  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
  };

  services.blueman.enable = true;
}
