_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.sessionVariables = {
      QT_QPA_PLATFORM = "wayland";
      SDL_VIDEODRIVER = "wayland,x11,windows";
      XDG_SESSION_TYPE = "wayland";
      LIBDECOR_ENABLE = "1";
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
      WLR_RENDERER_ALLOW_SOFTWARE = "0";
      GTK_THEME = "adw-gtk3-dark";
      ADW_DISABLE_PORTAL = "1";
    };

    environment.systemPackages = with pkgs; [
      adw-gtk3
      brightnessctl
      hyprcursor
      hyprland
      hyprlock
      hyprpaper
      hyprpicker
      hyprshade
      hyprshot
      kitty
      kitty-themes
      fuzzel
      screenrecord
      slurp
      waybar
      wf-recorder
      xwayland
    ];

    programs.hyprland = {
      enable = true;
      withUWSM = false;
      xwayland.enable = true;
    };
  };
}
