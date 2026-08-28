_: {
  flake.modules.homeManager.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config) palette;
      playerctl = "${pkgs.playerctl}/bin/playerctl";
      gamemoded = "${pkgs.gamemode}/bin/gamemoded";
      screenrecord = "${pkgs.screenrecord}/bin/screenrecord";

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

      # One button per everyday output device: click it and that device becomes
      # the default sink. Devices are matched by a node.name PREFIX, which is
      # the only identifier that survives real use — node ids are handed out per
      # session and change on every replug, node.description is presentation
      # text a wireplumber rule may rewrite, and a bluez node name ends in a
      # profile index (".1" for a2dp-sink) that changes when the profile does.
      # The prefix stops short of that index; for a USB device it is simply the
      # whole name.
      audioSink = pkgs.writeShellApplication {
        name = "waybar-audio-sink";

        runtimeInputs = with pkgs; [
          bluez # bluetoothctl
          coreutils
          gawk
          jq
          pipewire # pw-dump
          systemd # systemctl
          wireplumber # wpctl
        ];

        text = ''
          usage() {
            echo "usage: waybar-audio-sink {status|switch} PREFIX ICON LABEL [BT_ADDRESS]" >&2
            exit 2
          }

          # An empty prefix would match every sink in the graph, so the count is
          # checked before the arguments are bound rather than defaulted.
          [ "$#" -ge 4 ] || usage

          action="$1"
          prefix="$2"
          icon="$3"
          label="$4"
          address="''${5:-}"

          # Lowest-numbered sink whose node.name starts with the prefix — the
          # first one this device published. Prints nothing when the device is
          # not in the graph at all, which is the unplugged/disconnected case
          # rather than an error.
          sink_id() {
            pw-dump | jq -r --arg p "$prefix" '
              [ .[]
                | select(.info.props."media.class" == "Audio/Sink")
                | select(.info.props."node.name" // "" | startswith($p))
                | .id
              ] | min // empty
            '
          }

          is_default() {
            local current
            current="$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null |
              awk -F'"' '/node\.name = /{print $2; exit}' || true)"
            case "$current" in
              "$prefix"*) return 0 ;;
              *) return 1 ;;
            esac
          }

          status() {
            local class tip
            if [ -z "$(sink_id || true)" ]; then
              class=unavailable
              tip="$label — not connected"
            elif is_default; then
              class=active
              tip="$label — active"
            else
              class=inactive
              tip="$label — click to switch"
            fi
            printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$icon" "$class" "$tip"
          }

          switch() {
            local id
            id="$(sink_id || true)"

            # Absent from the graph. A bluetooth device can be summoned, so the
            # button works from the charging case and not only once the earbuds
            # are already up; an unplugged USB device cannot, and clicking it is
            # a no-op rather than an error nobody would see anyway.
            if [ -z "$id" ] && [ -n "$address" ]; then
              bluetoothctl connect "$address" >/dev/null 2>&1 || true
              for _ in $(seq 40); do
                id="$(sink_id || true)"
                if [ -n "$id" ]; then
                  break
                fi
                sleep 0.25
              done
            fi

            [ -n "$id" ] || return 0

            # This moves streams that are already playing, not just the next one
            # to start; streams pinned to a device in pavucontrol stay pinned,
            # exactly as when the default is changed there.
            wpctl set-default "$id"

            # Both pills listen on this signal, so the one losing default dims in
            # the same frame as the one gaining it instead of up to a poll later.
            #
            # Through the unit rather than by process name: waybar's binary is
            # wrapped, so it runs as ".waybar-wrapped" and `pkill -x waybar`
            # never matches it — while a loose `pkill waybar` matches THIS
            # script, which waybar spawned as "waybar-audio-sink", and kills the
            # switch mid-flight. `--kill-whom=main` addresses waybar itself and
            # nothing else in the cgroup.
            systemctl --user kill --kill-whom=main --signal=SIGRTMIN+9 waybar.service || true
          }

          case "$action" in
            status) status ;;
            switch) switch ;;
            *) usage ;;
          esac
        '';

        meta = {
          description = "Report and switch the default pipewire sink for a waybar button";
          mainProgram = "waybar-audio-sink";
        };
      };

      # `address` is the bluetooth adapter address, and its presence is what
      # tells the button it may connect the device rather than only route to it.
      sinkButton =
        {
          icon,
          label,
          prefix,
          address ? "",
        }:
        let
          args = lib.escapeShellArgs [
            prefix
            icon
            label
            address
          ];
        in
        {
          format = "{}";
          return-type = "json";
          exec = "${lib.getExe audioSink} status ${args}";
          on-click = "${lib.getExe audioSink} switch ${args}";
          interval = 2;
          signal = 9;
        };
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
              "custom/screenrecord"
              "custom/gamemode"
              "bluetooth"
              "network"
              "cpu"
              "memory"
              "temperature"
              "disk"
              "custom/audio-soundcore"
              "custom/audio-kraken"
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

            "custom/audio-soundcore" = sinkButton {
              icon = "󰋋";
              label = "soundcore Liberty 5 Pro";
              # No profile index: a2dp and hsp publish different node names off
              # the same address, and either one is still "the earbuds".
              prefix = "bluez_output.7C_E9_13_B0_E7_2C.";
              address = "7C:E9:13:B0:E7:2C";
            };

            "custom/audio-kraken" = sinkButton {
              icon = "󰋎";
              label = "Kraken 7.1 Chroma";
              prefix = "alsa_output.usb-Synaptics_USB-C_HEADSET_00000000-00.analog-stereo";
            };

            "custom/gamemode" = {
              format = "{}";
              return-type = "json";
              exec = "${gamemodeStatus}";
              interval = 2;
              tooltip = false;
            };

            # Emits empty text when idle, which waybar renders as a hidden
            # module — the pill exists only while it means something. Clicking
            # it is the mouse equivalent of pressing the keybind again.
            "custom/screenrecord" = {
              format = "{}";
              return-type = "json";
              exec = "${screenrecord} status";
              on-click = "${screenrecord} stop";
              interval = 1;
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
          #custom-audio-soundcore,
          #custom-audio-kraken,
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

          #custom-screenrecord,
          #custom-gamemode,
          #cpu,
          #memory,
          #temperature,
          #disk,
          #custom-audio-soundcore,
          #custom-audio-kraken,
          #bluetooth,
          #network,
          #pulseaudio,
          #tray {
            border-radius: 20px 5px 20px 5px;
          }

          #custom-screenrecord:hover,
          #custom-gamemode:hover,
          #cpu:hover,
          #memory:hover,
          #temperature:hover,
          #disk:hover,
          #custom-audio-soundcore:hover,
          #custom-audio-kraken:hover,
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
          #custom-audio-soundcore:hover,
          #custom-audio-kraken:hover,
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
          #custom-gamemode.off,
          #custom-audio-soundcore.unavailable,
          #custom-audio-kraken.unavailable {
            color: #${palette.muted};
            border-color: #${palette.muted};
          }

          /* The sink that owns the audio is filled rather than outlined — the
             same "this one is current" language as the active workspace. */
          #custom-audio-soundcore.active,
          #custom-audio-kraken.active {
            background: #${palette.accent};
            color: #${palette.background};
          }

          /* A device that is not in the graph keeps its dimmed identity on
             hover. The pill still responds, because clicking the earbuds
             connects them, but it must not read as "ready to switch". */
          #custom-audio-soundcore.unavailable:hover,
          #custom-audio-kraken.unavailable:hover {
            background: #${palette.muted};
            color: #${palette.background};
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

          /* The one pill allowed off the green scheme. A recording that is still
             running is worth breaking the palette for — and it is only on screen
             while that is true. */
          #custom-screenrecord {
            border: solid 2px;
            border-color: #${palette.urgent};
            background: #${palette.background};
            color: #${palette.urgent};
            transition: background 0.3s ease,
            border-radius 0.3s ease;
            margin-right: 8px;
            padding-left: 12px;
            padding-right: 12px;
          }

          #custom-screenrecord:hover {
            background: #${palette.urgent};
            color: #${palette.background};
          }

          #cpu,
          #memory,
          #temperature,
          #disk,
          #custom-audio-soundcore,
          #custom-audio-kraken,
          #bluetooth,
          #network,
          #pulseaudio {
            margin-right: 8px;
          }

          /* Icon-only pills on the right, sized like the gamemode toggle so the
             two of them read as one control rather than two odd-width buttons. */
          #custom-audio-soundcore,
          #custom-audio-kraken {
            padding-left: 12px;
            padding-right: 12px;
            min-width: 36px;
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
