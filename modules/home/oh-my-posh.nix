{ ... }: {
  flake.modules.homeManager.base = { config, pkgs, ... }: let palette = config.palette; in {
    programs.oh-my-posh = {
      enable = true;
      enableBashIntegration = true;
      package = pkgs.oh-my-posh;
      settings = {
        "$schema" = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json";
        version = 4;
        async = false;
        final_space = true;
        patch_pwsh_bleed = true;
        enable_cursor_positioning = true;
        shell_integration = true;
        upgrade = {
          auto = false;
          interval = "168h";
          notice = false;
          source = "cdn";
        };
        transient_prompt = {
          foreground = "#${palette.accent}";
          background = "transparent";
          newline = true;
          template = " ❯❯ {{ .AbsolutePWD }}\n ❯ ";
        };
        secondary_prompt = {
          foreground = "#${palette.accent}";
          background = "transparent";
          template = " ❯ ";
        };
        blocks = [
          {
            type = "prompt";
            alignment = "left";
            segments = [
              {
                type = "text";
                style = "plain";
                foreground = "#${palette.accent}";
                template = "╭─";
              }
              {
                type = "session";
                style = "diamond";
                foreground = "#${palette.accent}";
                background = "#${palette.background}";
                leading_diamond = "";
                template = "{{ .UserName }}";
              }
              {
                type = "root";
                style = "powerline";
                foreground = "#${palette.accentBright}";
                background = "#${palette.background}";
                powerline_symbol = "";
                template = "󱔋";
              }
              {
                type = "os";
                style = "powerline";
                foreground = "#${palette.accent}";
                background = "#${palette.background}";
                powerline_symbol = "";
                template = "{{ .Icon }} ";
              }
              {
                type = "path";
                style = "diamond";
                foreground = "#${palette.backgroundDark}";
                background = "#${palette.accent}";
                trailing_diamond = "";
                template = " 󰉖 {{ path .Path .Location }}";
                options = {
                  display_root = true;
                  style = "full";
                };
              }
            ];
          }
          {
            type = "prompt";
            alignment = "left";
            newline = true;
            segments = [
              {
                type = "text";
                style = "diamond";
                foreground = "#${palette.accent}";
                template = "╰─ ❯❯";
                options.always_enabled = true;
              }
            ];
          }
        ];
      };
    };
  };
}
