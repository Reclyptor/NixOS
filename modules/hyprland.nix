{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    hyprcursor
    hypridle
    hyprland
    hyprlock
    hyprpaper
    hyprpicker
    hyprshot
    hyprsunset
    kitty
    kitty-themes
    waybar
    wofi
    xwayland
  ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.waybar.enable = true;
}
