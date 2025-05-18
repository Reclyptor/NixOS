{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    hyprcursor
    hypridle
    hyprland
    hyprlock
    hyprpaper
    hyprpicker
    hyprsunset
    kitty
    kitty-themes
    waybar
    wofi
  ];
}
