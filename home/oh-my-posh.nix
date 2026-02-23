{ config, pkgs, ... }: {
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
        foreground = "#A4C639";
        background = "transparent";
        newline = true;
        template = " ❯❯ {{ .AbsolutePWD }}\n ❯ ";
      };
      secondary_prompt = {
        foreground = "#A4C639";
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
              foreground = "#A4C639";
              template = "╭─";
            }
            {
              type = "session";
              style = "diamond";
              foreground = "#A4C639";
              background = "#141914";
              leading_diamond = "";
              template = "{{ .UserName }}";
            }
            {
              type = "root";
              style = "powerline";
              foreground = "#e5fb79";
              background = "#141914";
              powerline_symbol = "";
              template = "󱔋";
            }
            {
              type = "os";
              style = "powerline";
              foreground = "#A4C639";
              background = "#141914";
              powerline_symbol = "";
              template = "{{ .Icon }} ";
            }
            {
              type = "path";
              style = "diamond";
              foreground = "#0C0F0C";
              background = "#A4C639";
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
              foreground = "#A4C639";
              template = "╰─ ❯❯";
              options.always_enabled = true;
            }
          ];
        }
      ];
    };
  };
}
