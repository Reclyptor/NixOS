{ ... }: {
  flake.modules.homeManager.base =
    { config, pkgs, ... }:
    let
      palette = config.palette;
      playerctl = "${pkgs.playerctl}/bin/playerctl";
      gamemoded = "${pkgs.gamemode}/bin/gamemoded";

      # These modules used to shell out through `bash -lc`, which sources the full
      # login profile on every tick — four modules at interval 1 plus gamemode at
      # 2 meant roughly three login shells per second, forever, each one re-running
      # the secret exports in bash/00-init.nix. Plain scripts with absolute binary
      # paths: no profile, no PATH search, no shell startup. It also gets the JSON
      # out of triple-escaped one-liners and into something readable.
      mediaPlay = pkgs.writeShellScript "waybar-media-play" ''
        state=$(${playerctl} status 2>/dev/null || echo Stopped)
        case "$state" in
          Playing) printf '{"text":"󰏤"}\n' ;;
          Paused)  printf '{"text":"󰐊"}\n' ;;
          *)       printf '{"text":"󰐊","class":"off"}\n' ;;
        esac
      '';

      mediaShuffle = pkgs.writeShellScript "waybar-media-shuffle" ''
        state=$(${playerctl} shuffle 2>/dev/null || echo Off)
        if [ "$state" = "On" ]; then
          printf '{"text":"󰒟"}\n'
        else
          printf '{"text":"","class":"off"}\n'
        fi
      '';

      mediaLoop = pkgs.writeShellScript "waybar-media-loop" ''
        state=$(${playerctl} loop 2>/dev/null || echo None)
        case "$state" in
          Track)    printf '{"text":"󰑘"}\n' ;;
          Playlist) printf '{"text":"󰑖"}\n' ;;
          *)        printf '{"text":"󰑖","class":"none"}\n' ;;
        esac
      '';

      mediaLoopToggle = pkgs.writeShellScript "waybar-media-loop-toggle" ''
        state=$(${playerctl} loop 2>/dev/null || echo None)
        case "$state" in
          None)     ${playerctl} loop Playlist ;;
          Playlist) ${playerctl} loop Track ;;
          *)        ${playerctl} loop None ;;
        esac
      '';

      gamemodeStatus = pkgs.writeShellScript "waybar-gamemode" ''
        status=$(${gamemoded} -s 2>/dev/null || true)
        case "$status" in
          *"is active"*) printf '{"text":"󰊴"}\n' ;;
          *)             printf '{"text":"󰊴","class":"off"}\n' ;;
        esac
      '';
    in
    {
      # Waybar configuration
      programs.waybar = {
        enable = true;
        systemd.enable = true;

        settings = {
          mainBar = {
            margin = "5 20 0 20";

            modules-left = [
              "custom/launcher"
              "hyprland/workspaces"
              "mpris"
              "custom/media-shuffle"
              "custom/media-prev"
              "custom/media-play"
              "custom/media-next"
              "custom/media-loop"
            ];
            modules-center = [ "clock" ];
            modules-right = [
              "custom/gamemode"
              "bluetooth"
              "network"
              "cpu"
              "memory"
              "temperature"
              "disk"
              "pulseaudio"
              "tray"
            ];

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
              on-click = "${playerctl} previous";
              tooltip = false;
            };

            "custom/media-play" = {
              format = "{}";
              return-type = "json";
              exec = "${mediaPlay}";
              on-click = "${playerctl} play-pause";
              interval = 1;
              tooltip = false;
            };

            "custom/media-next" = {
              format = "󰒭";
              on-click = "${playerctl} next";
              tooltip = false;
            };

            "custom/media-shuffle" = {
              format = "{}";
              return-type = "json";
              exec = "${mediaShuffle}";
              on-click = "${playerctl} shuffle toggle";
              interval = 1;
              tooltip = false;
            };

            "custom/media-loop" = {
              format = "{}";
              return-type = "json";
              exec = "${mediaLoop}";
              on-click = "${mediaLoopToggle}";
              interval = 1;
              tooltip = false;
            };

            "custom/gamemode" = {
              format = "{}";
              return-type = "json";
              exec = "${gamemodeStatus}";
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
              format-icons = [
                ""
                ""
                ""
              ];
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
                default = [
                  "🔈"
                  "🔉"
                  "🔊"
                ];
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

          /* Every module is a bordered pill: accent outline on a dark fill, with
             corners rounded on one diagonal that flips on hover. Left-side pills
             round the NE/SW corners, right-side pills the NW/SE corners, and the
             clock rounds its bottom. */
          #custom-launcher,
          #workspaces button,
          #mpris,
          #custom-media-shuffle,
          #custom-media-prev,
          #custom-media-play,
          #custom-media-next,
          #custom-media-loop,
          #custom-gamemode,
          #cpu,
          #memory,
          #temperature,
          #disk,
          #bluetooth,
          #clock,
          #network,
          #pulseaudio,
          #tray {
            border: solid 2px;
            border-color: #${palette.accent};
            background: #${palette.background};
            color: #${palette.accent};
            transition: background 0.3s ease,
            border-radius 0.3s ease;
          }

          #custom-launcher,
          #workspaces button,
          #mpris,
          #custom-media-shuffle,
          #custom-media-prev,
          #custom-media-play,
          #custom-media-next,
          #custom-media-loop {
            border-radius: 5px 20px 5px 20px;
          }

          #custom-launcher:hover,
          #workspaces button:hover,
          #workspaces button.active,
          #mpris:hover,
          #custom-media-shuffle:hover,
          #custom-media-prev:hover,
          #custom-media-play:hover,
          #custom-media-next:hover,
          #custom-media-loop:hover {
            border-radius: 20px 5px 20px 5px;
          }

          #custom-gamemode,
          #cpu,
          #memory,
          #temperature,
          #disk,
          #bluetooth,
          #network,
          #pulseaudio,
          #tray {
            border-radius: 20px 5px 20px 5px;
          }

          #custom-gamemode:hover,
          #cpu:hover,
          #memory:hover,
          #temperature:hover,
          #disk:hover,
          #bluetooth:hover,
          #network:hover,
          #pulseaudio:hover,
          #tray:hover {
            border-radius: 5px 20px 5px 20px;
          }

          #clock {
            border-radius: 5px 5px 20px 20px;
          }

          #clock:hover {
            border-radius: 20px 20px 5px 5px;
          }

          /* Hover inverts the pill; workspaces get a translucent tint instead. */
          #custom-launcher:hover,
          #mpris:hover,
          #custom-media-shuffle:hover,
          #custom-media-prev:hover,
          #custom-media-play:hover,
          #custom-media-next:hover,
          #custom-media-loop:hover,
          #custom-gamemode:hover,
          #cpu:hover,
          #memory:hover,
          #temperature:hover,
          #disk:hover,
          #bluetooth:hover,
          #clock:hover,
          #network:hover,
          #pulseaudio:hover,
          #tray:hover {
            background: #${palette.accent};
            color: #${palette.background};
          }

          #workspaces button:hover {
            background: rgba(${palette.accentRgb}, 0.2);
          }

          #workspaces button.active {
            background: #${palette.accent};
            color: #${palette.background};
            font-weight: bold;
          }

          #workspaces button.empty {
            opacity: 0.4;
          }

          /* Inactive toggles dim to the muted olive. */
          #custom-media-shuffle.off,
          #custom-media-play.off,
          #custom-media-loop.none,
          #custom-gamemode.off {
            color: #${palette.muted};
            border-color: #${palette.muted};
          }

          /* Per-module geometry. */
          #custom-launcher {
            padding-left: 10px;
            padding-right: 10px;
          }

          #workspaces {
            margin-left: 8px;
          }

          #workspaces button {
            padding: 0 8px;
            margin-right: 4px;
            transition: all 0.3s ease;
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
          }

          #custom-media-shuffle,
          #custom-media-prev,
          #custom-media-play,
          #custom-media-next,
          #custom-media-loop {
            min-width: 28px;
          }

          #custom-gamemode {
            margin-right: 8px;
            padding-left: 12px;
            padding-right: 12px;
            min-width: 36px;
          }

          #cpu,
          #memory,
          #temperature,
          #disk,
          #bluetooth,
          #network,
          #pulseaudio {
            margin-right: 8px;
          }

          #cpu,
          #memory,
          #temperature,
          #disk,
          #bluetooth {
            padding-left: 10px;
            padding-right: 10px;
          }

          #network {
            padding-left: 15px;
            padding-right: 15px;
          }

          #pulseaudio {
            padding-left: 0px;
            padding-right: 0px;
          }

          #clock,
          #tray {
            padding-left: 16px;
            padding-right: 16px;
          }

          #tooltip {
            background: #${palette.background};
            color: #${palette.accent};
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
