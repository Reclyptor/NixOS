{ config, pkgs, ... }: {
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --cmd ${pkgs.hyprland}/bin/start-hyprland";
        user = "reclyptor";
      };
    };
  };
}
