_: {
  flake.modules.nixos.workstation =
    { pkgs, ... }:
    {
      # gamescope runs the game in a nested session and presents one XWayland
      # window to the host compositor. That window's _NET_WM_PID is gamescope's
      # own PID, not the game's — the game is a grandchild process several layers
      # down (reaper -> pressure-vessel -> proton -> the .exe).
      #
      # Discord's "Share Stream Audio" resolves the shared window to its
      # _NET_WM_PID and then captures the PipeWire stream owned by that PID (the
      # same X11-capture path the `discordx` wrapper exists to force; see
      # overlays/discord.nix). gamescope owns no audio stream, so the match finds
      # nothing and the stream goes out silent even though the game is plainly
      # audible locally — its audio belongs to the nested .exe, a PID the shared
      # window never advertises.
      #
      # This points the window back at the process that actually makes its sound:
      # it finds the gamescope window, walks the process tree down to the
      # descendant that owns an audio output stream, and rewrites _NET_WM_PID to
      # that PID. _NET_WM_PID is only a hint property — gamescope does not read it
      # back — so overwriting it changes nothing but who Discord blames the audio
      # on. Run it once the game is producing sound, then start (or restart)
      # Share Stream Audio so Discord re-reads the corrected PID.
      environment.systemPackages = [
        (pkgs.writeShellApplication {
          name = "gamescope-stream-audio";
          runtimeInputs = with pkgs; [
            coreutils
            gawk
            gnused
            jq
            procps
            wmctrl
            xorg.xprop
            pipewire # pw-dump
          ];
          text = ''
            export DISPLAY="''${DISPLAY:-:0}"

            die() {
              echo "gamescope-stream-audio: $*" >&2
              exit 1
            }

            # PPid without tripping over a comm field that contains spaces or
            # parentheses: drop everything through the last ") ", leaving
            # "<state> <ppid> ..." to read the second field from.
            ppid_of() {
              local p=$1 rest
              [ -r "/proc/$p/stat" ] || return 1
              rest=$(sed -e 's/^.*) //' "/proc/$p/stat") || return 1
              awk '{ print $2 }' <<<"$rest"
            }

            # Is $1 the same process as, or a descendant of, ancestor $2?
            is_descendant() {
              local p=$1 anc=$2
              while [ -n "$p" ] && [ "$p" -gt 1 ]; do
                [ "$p" = "$anc" ] && return 0
                p=$(ppid_of "$p") || return 1
              done
              return 1
            }

            # PIDs that own a live audio output stream right now.
            audio_pids() {
              pw-dump 2>/dev/null | jq -r '
                .[]
                | select(.type == "PipeWire:Interface:Node")
                | .info.props
                | select(.["media.class"] == "Stream/Output/Audio")
                | .["application.process.id"]
                | select(. != null)
              ' | sort -u
            }

            fixed=0
            # wmctrl -lpx columns: window-id  desktop  pid  wm-class  host  title
            while read -r win _ gpid class _; do
              case "''${class,,}" in
                *gamescope*) ;;
                *) continue ;;
              esac

              target=""
              while read -r apid; do
                if is_descendant "$apid" "$gpid"; then
                  target=$apid
                  break
                fi
              done < <(audio_pids)

              if [ -z "$target" ]; then
                echo "gamescope-stream-audio: no audio stream under gamescope PID" \
                  "$gpid yet — is the game making sound?" >&2
                continue
              fi

              xprop -id "$win" -f _NET_WM_PID 32c -set _NET_WM_PID "$target"
              echo "gamescope-stream-audio: $win ($class) _NET_WM_PID $gpid -> $target"
              fixed=1
            done < <(wmctrl -lpx)

            [ "$fixed" = 1 ] || die "no gamescope window with a capturable audio stream found"
            echo "gamescope-stream-audio: done — now (re)enable Discord 'Share Stream Audio' so it re-reads the PID"
          '';

          meta = {
            description = "Rewrite a gamescope window's _NET_WM_PID to its nested game's audio PID so Discord screen-share captures game sound";
            mainProgram = "gamescope-stream-audio";
          };
        })
      ];
    };
}
