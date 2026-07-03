{ ... }: {
  flake.modules.homeManager.base = { config, ... }: let palette = config.palette; in {
    # Waybar configuration
    programs.waybar = {
      enable = true;
      systemd.enable = true;
      
      settings = {
        mainBar = {
          margin = "5 20 0 20";
          
          modules-left = [ "custom/launcher" "hyprland/workspaces" "mpris" "custom/media-shuffle" "custom/media-prev" "custom/media-play" "custom/media-next" "custom/media-loop" ];
          modules-center = [ "clock" ];
          modules-right = [ "custom/gamemode" "bluetooth" "network" "cpu" "memory" "temperature" "disk" "pulseaudio" "tray" ];

          "custom/launcher" = {
            format = "  ";
            interval = 7200;
            on-click = "pkill fuzzel || fuzzel";
            signal = 8;
          };

          "hyprland/workspaces" = {
            format = "{icon}";
            format-icons = {
              active = "󰮯";
              default = "󰊠";
              empty = "󰝦";
            };
            persistent-workspaces = {
              "*" = 5;
            };
          };

          mpris = {
            format = "{player_icon} {dynamic}";
            format-paused = "{status_icon} {dynamic}";
            interval = 1;
            player-icons = {
              default = "󰎇";
              spotify = "󰓇";
              mpv = "󰐹";
              firefox = "󰈹";
            };
            status-icons = {
              paused = "󰏤";
            };
            max-length = 60;
          };

          "custom/media-prev" = {
            format = "󰒮";
            on-click = "playerctl previous";
            tooltip = false;
          };

          "custom/media-play" = {
            format = "{}";
            return-type = "json";
            exec = "bash -lc 'state=$(playerctl status 2>/dev/null || echo Stopped); case \"$state\" in Playing) echo \"{\\\"text\\\":\\\"󰏤\\\"}\" ;; Paused) echo \"{\\\"text\\\":\\\"󰐊\\\"}\" ;; *) echo \"{\\\"text\\\":\\\"󰐊\\\",\\\"class\\\":\\\"off\\\"}\" ;; esac'";
            on-click = "playerctl play-pause";
            interval = 1;
            tooltip = false;
          };

          "custom/media-next" = {
            format = "󰒭";
            on-click = "playerctl next";
            tooltip = false;
          };

          "custom/media-shuffle" = {
            format = "{}";
            return-type = "json";
            exec = "bash -lc 'state=$(playerctl shuffle 2>/dev/null || echo Off); if [ \"$state\" = \"On\" ]; then echo \"{\\\"text\\\":\\\"󰒟\\\"}\"; else echo \"{\\\"text\\\":\\\"\\\",\\\"class\\\":\\\"off\\\"}\"; fi'";
            on-click = "playerctl shuffle toggle";
            interval = 1;
            tooltip = false;
          };

          "custom/media-loop" = {
            format = "{}";
            return-type = "json";
            exec = "bash -lc 'state=$(playerctl loop 2>/dev/null || echo None); case \"$state\" in None) echo \"{\\\"text\\\":\\\"󰑖\\\",\\\"class\\\":\\\"none\\\"}\" ;; Track) echo \"{\\\"text\\\":\\\"󰑘\\\"}\" ;; Playlist) echo \"{\\\"text\\\":\\\"󰑖\\\"}\" ;; *) echo \"{\\\"text\\\":\\\"󰑖\\\",\\\"class\\\":\\\"none\\\"}\" ;; esac'";
            on-click = "bash -lc 'state=$(playerctl loop 2>/dev/null || echo None); case \"$state\" in None) playerctl loop Playlist ;; Playlist) playerctl loop Track ;; Track) playerctl loop None ;; *) playerctl loop None ;; esac'";
            interval = 1;
            tooltip = false;
          };

          "custom/gamemode" = {
            format = "{}";
            return-type = "json";
            exec = "bash -lc 'status=$(gamemoded -s 2>/dev/null || true); if [[ \"$status\" == *\"is active\"* ]]; then echo \"{\\\"text\\\":\\\"󰊴\\\"}\"; else echo \"{\\\"text\\\":\\\"󰊴\\\",\\\"class\\\":\\\"off\\\"}\"; fi'";
            interval = 2;
            tooltip = false;
          };

          cpu = {
            format = "  {usage}%";
            interval = 2;
            on-click = "kitty --class btop -e btop";
          };

          memory = {
            format = "  {percentage}%";
            interval = 2;
          };

          temperature = {
            critical-threshold = 85;
            format = "{icon} {temperatureC}°C";
            format-icons = [ "" "" "" ];
          };

          disk = {
            interval = 30;
            format = "󰋊 {percentage_used}%";
            path = "/";
            tooltip-format = "{path}: {used}/{total} ({percentage_used}%)";
          };

          bluetooth = {
            format = " {status}";
            format-connected = " {device_alias}";
            format-connected-battery = " {device_alias} {device_battery_percentage}%";
            tooltip-format = "{controller_alias}\t{controller_address}";
            tooltip-format-connected = "{controller_alias}\t{controller_address}\n{num_connections} connected";
            on-click = "blueman-manager";
          };

          clock = {
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
            format = "{:%A | %d %b %Y | %H:%M:%S}";
            interval = 1;
          };

          network = {
            format-wifi = "󰖩  {essid} ({signalStrength}%)";
            format-ethernet = "󰈀 Ethernet";
            format-disconnected = "󰖪 Disconnected";
            on-click = "nm-connection-editor";
          };

          pulseaudio = {
            reverse-scrolling = 1;
            format = "{volume}% {icon}";
            format-bluetooth = "{volume}% {icon}";
            format-muted = " {format_source}";
            format-source-muted = "Muted 🚫";
            format-icons = {
              headphone = "🎧";
              default = [ "🔈" "🔉" "🔊" ];
            };
            on-click = "pavucontrol";
            min-length = 13;
          };

          tray = {
            icon-size = 16;
            spacing = 4;
          };
        };
      };

      style = ''
        * {
          border: none;
          border-radius: 0;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          min-height: 0px;
        }

        window#waybar {
          background: transparent;
        }

        window#waybar.hidden {
          opacity: 0.2;
        }

        #custom-launcher {
          padding-left: 10px;
          padding-right: 10px;
          border-radius: 5px 20px 5px 20px;
          border: solid 2px;
          border-color: #${palette.accent};
          transition: background 0.3s ease,
          border-radius 0.3s ease;
          background: #${palette.background};
          color: #${palette.accent};
        }

        #custom-launcher:hover {
          border-radius: 20px 5px 20px 5px;
          background: #${palette.accent};
          color: #${palette.background};
        }

        #workspaces {
          margin-left: 8px;
        }

        #workspaces button {
          padding: 0 8px;
          border-radius: 5px 20px 5px 20px;
          border: solid 2px #${palette.accent};
          background: #${palette.background};
          color: #${palette.accent};
          transition: all 0.3s ease;
          margin-right: 4px;
        }

        #workspaces button:hover {
          border-radius: 20px 5px 20px 5px;
          background: rgba(${palette.accentRgb}, 0.2);
        }

        #workspaces button.active {
          border-radius: 20px 5px 20px 5px;
          background: #${palette.accent};
          color: #${palette.background};
          font-weight: bold;
        }

        #workspaces button.empty {
          opacity: 0.4;
        }

        #mpris,
        #custom-media-shuffle,
        #custom-media-prev,
        #custom-media-play,
        #custom-media-next,
        #custom-media-loop {
          margin-left: 8px;
          padding-left: 12px;
          padding-right: 12px;
          border-radius: 5px 20px 5px 20px;
          border: solid 2px;
          border-color: #${palette.accent};
          transition: background 0.3s ease-in-out,
          border-radius 0.3s ease-in-out;
          background: #${palette.background};
          color: #${palette.accent};
        }

        #custom-media-shuffle,
        #custom-media-prev,
        #custom-media-play,
        #custom-media-next,
        #custom-media-loop {
          min-width: 28px;
        }

        #custom-media-shuffle.off {
          color: #${palette.muted};
          border-color: #${palette.muted};
        }

        #custom-media-play.off {
          color: #${palette.muted};
          border-color: #${palette.muted};
        }

        #custom-media-loop.none {
          color: #${palette.muted};
          border-color: #${palette.muted};
        }

        #custom-gamemode {
          margin-right: 8px;
          padding-left: 12px;
          padding-right: 12px;
          min-width: 36px;
          border-radius: 20px 5px 20px 5px;
          border: solid 2px;
          border-color: #${palette.accent};
          transition: background 0.3s ease-in-out,
          border-radius 0.3s ease-in-out;
          background: #${palette.background};
          color: #${palette.accent};
        }

        #custom-gamemode.off {
          color: #${palette.muted};
          border-color: #${palette.muted};
        }

        #mpris:hover,
        #custom-media-shuffle:hover,
        #custom-media-prev:hover,
        #custom-media-play:hover,
        #custom-media-next:hover,
        #custom-media-loop:hover {
          border-radius: 20px 5px 20px 5px;
          background: #${palette.accent};
          color: #${palette.background};
        }

        #custom-gamemode:hover {
          border-radius: 5px 20px 5px 20px;
          background: #${palette.accent};
          color: #${palette.background};
        }

        #cpu,
        #memory,
        #temperature,
        #disk,
        #bluetooth {
          margin-right: 8px;
          padding-left: 10px;
          padding-right: 10px;
          border-radius: 20px 5px 20px 5px;
          border: solid 2px;
          border-color: #${palette.accent};
          transition: background 0.3s ease-in-out,
          border-radius 0.3s ease-in-out;
          background: #${palette.background};
          color: #${palette.accent};
        }

        #cpu:hover,
        #memory:hover,
        #temperature:hover,
        #disk:hover,
        #bluetooth:hover {
          border-radius: 5px 20px 5px 20px;
          background: #${palette.accent};
          color: #${palette.background};
        }

        #clock {
          padding-left: 16px;
          padding-right: 16px;
          border-radius: 5px 5px 20px 20px;
          border: solid 2px;
          border-color: #${palette.accent};
          transition: background 0.3s ease,
          border-radius 0.3s ease;
          background: #${palette.background};
          color: #${palette.accent};
        }

        #clock:hover {
          border-radius: 20px 20px 5px 5px;
          background: #${palette.accent};
          color: #${palette.background};
        }

        #network {
          margin-right: 8px;
          padding-right: 15px;
          padding-left: 15px;
          border-radius: 20px 5px 20px 5px;
          border: solid 2px;
          border-color: #${palette.accent};
          transition: background 0.3s ease,
          border-radius 0.3s ease;
          background: #${palette.background};
          color: #${palette.accent};
        }

        #network:hover {
          border-radius: 5px 20px 5px 20px;
          background: #${palette.accent};
          color: #${palette.background};
        }

        #pulseaudio {
          margin-right: 8px;
          border-radius: 20px 5px 20px 5px;
          padding-left: 0px;
          padding-right: 0px;
          border: solid 2px;
          border-color: #${palette.accent};
          transition: background 0.3s ease,
          border-radius 0.3s ease;
          background: #${palette.background};
          color: #${palette.accent};
        }

        #pulseaudio:hover {
          border-radius: 5px 20px 5px 20px;
          background: #${palette.accent};
          color: #${palette.background};
        }

        #tooltip {
          background: #${palette.background};
          color: #${palette.accent};
        }

        #tray {
          padding-left: 16px;
          padding-right: 16px;
          border-radius: 20px 5px 20px 5px;
          border: solid 2px;
          border-color: #${palette.accent};
          transition: background 0.3s ease,
          border-radius 0.3s ease;
          background: #${palette.background};
          color: #${palette.accent};
        }

        #tray:hover {
          border-radius: 5px 20px 5px 20px;
          background: #${palette.accent};
          color: #${palette.background};
        }

        @keyframes blink {
          to {
            background-color: #ffffff;
            color: #484a4a;
          }
        }
      '';
    };
  };
}
