{ ... }: {
  flake.modules.homeManager.base = { ... }: {
    # Hypridle configuration
    services.hypridle = {
      enable = false;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };

        listener = [
          {
            timeout = 300; # 5 minutes - dim display
            on-timeout = "brightnessctl -s set 10";
            on-resume = "brightnessctl -r";
          }
          {
            timeout = 600; # 10 minutes - lock session
            on-timeout = "loginctl lock-session";
          }
          {
            timeout = 900; # 15 minutes - display off
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
        ];
      };
    };
  };
}
