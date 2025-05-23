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
}
