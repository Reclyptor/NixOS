_: {
  flake.modules.homeManager.base = {
    # Blank the displays after idling; locking stays manual ($mainMod, L).
    services.hypridle = {
      enable = true;

      settings = {
        general = {
          # Displays stay off after a manual suspend without this.
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };

        listener = [
          {
            timeout = 900;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
        ];
      };
    };
  };
}
