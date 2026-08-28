_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (final: _prev: {
        # The video twin of `hyprshot -m region`: slurp picks the rectangle,
        # wf-recorder records it, and one command toggles between the two so a
        # single keybinding can both start and stop.
        #
        # State is one pidfile. Its mtime doubles as the recording's start time,
        # which is what the waybar timer counts from — no second file to keep in
        # sync, and nothing survives a reboot that shouldn't.
        screenrecord = final.writeShellApplication {
          name = "screenrecord";

          runtimeInputs = with final; [
            coreutils
            gawk
            hyprland # hyprctl
            jq
            libnotify # notify-send, errors only
            slurp
            wf-recorder
            wireplumber # wpctl
          ];

          text = ''
            state="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/screenrecord.pid"
            log="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/screenrecord.log"
            outdir="$HOME/Recordings"

            usage() {
              echo "usage: screenrecord {region|output} [--audio] | stop | status" >&2
              exit 2
            }

            # Prints the PID of a live wf-recorder, or fails. A pidfile whose
            # process is gone means the last run crashed or the box rebooted;
            # clear it so the next toggle starts instead of trying to stop.
            running() {
              local pid
              [ -r "$state" ] || return 1
              pid="$(cat "$state")"
              if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                printf '%s\n' "$pid"
                return 0
              fi
              rm -f "$state"
              return 1
            }

            stop() {
              local pid
              pid="$(running)" || return 0

              # SIGINT, not SIGTERM. wf-recorder writes the MP4 trailer on
              # interrupt; killed any other way the file has no index and will
              # not play back.
              kill -INT "$pid" 2>/dev/null || true
              for _ in $(seq 100); do
                kill -0 "$pid" 2>/dev/null || break
                sleep 0.05
              done
              rm -f "$state"
            }

            # slurp returns "x,y WxH" at whatever size was dragged; this prints
            # "x,y W H" so the caller gets the dimensions on their own. yuv420p
            # needs both even and wf-recorder rounds down on its own, but it does
            # that after we have already picked a codec from these numbers —
            # rounding here keeps that choice matched to what actually gets
            # encoded at the 4096 boundary.
            region_geometry() {
              local geom pos size w h
              geom="$(slurp)" || return 1
              pos="''${geom%% *}"
              size="''${geom##* }"
              w="''${size%%x*}"
              h="''${size##*x}"
              w=$((w - w % 2))
              h=$((h - h % 2))
              [ "$w" -ge 2 ] && [ "$h" -ge 2 ] || return 1
              printf '%s %d %d\n' "$pos" "$w" "$h"
            }

            # "name W H" for the monitor holding focus.
            focused_output() {
              hyprctl -j monitors |
                jq -r '.[] | select(.focused) | "\(.name) \(.width) \(.height)"'
            }

            # NVENC's H.264 encoder refuses anything over 4096 in either
            # dimension, and this desktop is 5120 wide — a full-monitor capture
            # dies at avcodec_open2 with "Width 5120 exceeds 4096". H.264 stays
            # the default because it plays everywhere; oversized captures fall to
            # HEVC, which the same silicon encodes up to 8192.
            nvenc_codec() {
              if [ "$1" -le 4096 ] && [ "$2" -le 4096 ]; then
                printf 'h264_nvenc\n'
              else
                printf 'hevc_nvenc\n'
              fi
            }

            # What you hear, not what the mic hears: the default sink's monitor
            # source. wpctl reports the node name; pipewire-pulse exposes it to
            # wf-recorder's pulse backend as "<node>.monitor".
            sink_monitor() {
              local node
              node="$(wpctl inspect @DEFAULT_AUDIO_SINK@ |
                awk -F'"' '/node\.name = /{print $2; exit}')"
              [ -n "$node" ] || return 1
              printf '%s.monitor\n' "$node"
            }

            start() {
              local mode="$1" audio="$2"
              local args=() info pos monitor w h device file pid

              case "$mode" in
                region)
                  # Cancelled selection: nothing to record, nothing to report.
                  info="$(region_geometry)" || exit 0
                  read -r pos w h <<<"$info"
                  args+=(-g "$pos ''${w}x''${h}")
                  ;;
                output)
                  info="$(focused_output)"
                  read -r monitor w h <<<"$info"
                  args+=(-o "$monitor")
                  ;;
              esac

              if [ "$audio" = yes ]; then
                # Audio was asked for explicitly, so a missing sink is an error,
                # not a reason to quietly record a silent video.
                if ! device="$(sink_monitor)"; then
                  notify-send -u critical "Screen recording failed" \
                    "No default audio sink to record from"
                  exit 1
                fi
                args+=("--audio=$device")
              fi

              mkdir -p "$outdir"
              file="$outdir/$(date +%Y%m%d_%H%M%S)_screenrecord.mp4"

              # 60fps is a cap, not a target: wf-recorder otherwise captures at
              # panel rate, and this panel runs at 240. NVENC because software
              # x264 cannot keep up with a 5120-wide capture.
              wf-recorder "''${args[@]}" \
                -f "$file" \
                -r 60 \
                -c "$(nvenc_codec "$w" "$h")" \
                -x yuv420p \
                -p preset=p5 \
                -p rc=vbr \
                -p cq=23 \
                >"$log" 2>&1 &

              pid=$!
              printf '%s\n' "$pid" >"$state"

              # A failed start is otherwise invisible — the waybar pill simply
              # never appears and nothing says why. Recording itself stays quiet;
              # errors do not.
              sleep 0.5
              if ! kill -0 "$pid" 2>/dev/null; then
                rm -f "$state"
                notify-send -u critical "Screen recording failed" \
                  "$(tail -n 3 "$log")"
              fi
            }

            status() {
              local started now elapsed
              if ! running >/dev/null; then
                printf '{"text":""}\n'
                return 0
              fi
              started="$(stat -c %Y "$state")"
              now="$(date +%s)"
              elapsed=$((now - started))
              printf '{"text":"  %d:%02d","class":"recording"}\n' \
                "$((elapsed / 60))" "$((elapsed % 60))"
            }

            case "''${1:-}" in
              region | output)
                mode="$1"
                shift
                audio=no
                if [ "''${1:-}" = --audio ]; then
                  audio=yes
                fi
                if running >/dev/null; then
                  stop
                else
                  start "$mode" "$audio"
                fi
                ;;
              stop) stop ;;
              status) status ;;
              *) usage ;;
            esac
          '';

          meta = {
            description = "Toggle region or output screen recording via slurp and wf-recorder";
            mainProgram = "screenrecord";
          };
        };
      })
    ];
  };
}
