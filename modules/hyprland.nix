{ pkgs, ... }: {
  environment.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland,x11,windows";
    XDG_SESSION_TYPE = "wayland";
    LIBDECOR_ENABLE = "1";
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_RENDERER_ALLOW_SOFTWARE = "0";
  };

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
