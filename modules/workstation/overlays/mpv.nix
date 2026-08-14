_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (final: _prev: {
        # Discord captures through WebRTC's X11 capturer (see overlays/discord.nix),
        # which only enumerates X11 windows, so a natively-Wayland mpv never shows up
        # in the share picker. Dropping WAYLAND_DISPLAY makes mpv fall back to
        # XWayland, where it gets a real window carrying a _NET_WM_PID.
        #
        # "Share Stream Audio" then matches that window's PID against the PulseAudio
        # sink-input list, and mpv's default `ao=pipewire` publishes a node with no
        # application.process.id at all, so it could never match. Going through the
        # pipewire-pulse compatibility layer restores that property.
        #
        # This is a sibling launcher, not a replacement: plain `mpv` keeps rendering
        # natively on Wayland and talking to PipeWire directly.
        mpvx =
          final.runCommand "mpvx-${final.mpv.version}"
            {
              nativeBuildInputs = [ final.makeBinaryWrapper ];
              meta = {
                description = "mpv forced onto XWayland and pipewire-pulse so Discord can share it";
                inherit (final.mpv.unwrapped.meta) homepage license;
                mainProgram = "mpvx";
              };
            }
            ''
              makeWrapper ${final.mpv}/bin/mpv $out/bin/mpvx \
                --unset WAYLAND_DISPLAY \
                --add-flags "--ao=pulse"

              # MimeType is dropped so this entry never competes for the default video
              # handler; Icon=mpv resolves against the mpv package's own hicolor theme.
              mkdir -p $out/share/applications
              sed -e 's/^Exec=mpv /Exec=mpvx /' \
                  -e 's/^TryExec=mpv$/TryExec=mpvx/' \
                  -e 's/^Name=mpv Media Player$/Name=mpv (X11 Capture)/' \
                  -e '/^Name\[/d' \
                  -e '/^MimeType=/d' \
                  ${final.mpv}/share/applications/mpv.desktop \
                  > $out/share/applications/mpvx.desktop
            '';
      })
    ];
  };
}
