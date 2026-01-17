{ config, pkgs, ... }: {
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --sessions ${pkgs.hyprland}/share/wayland-sessions";
        user = "reclyptor";
      };
    };
  };
}
