{ ... }: {
  flake.modules.homeManager.base = { pkgs, ... }: {
    # Home-manager handles themes and icons
    gtk = {
      enable = true;
      theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };
      iconTheme = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
      };
      gtk3.extraConfig = {
        "gtk-application-prefer-dark-theme" = 1;
      };
      gtk4 = {
        theme = null;
        extraConfig = {
          "gtk-application-prefer-dark-theme" = 1;
        };
      };
    };

    # Modern cursor management. `enable` must be explicit — relying on the mere
    # presence of this block to switch cursor generation on is deprecated.
    home.pointerCursor = {
      enable = true;
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };

    # The "It Just Works" dark mode variables
    home.sessionVariables = {
      GTK_THEME = "adw-gtk3-dark";
      ADW_DISABLE_PORTAL = "1";
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };

    qt = {
      enable = true;
      # "gtk" is deprecated and ambiguous: it meant the legacy qtstyleplugins
      # build. "gtk3" selects the modern native Qt GTK3 platform theme.
      platformTheme.name = "gtk3";
    };
  };
}
