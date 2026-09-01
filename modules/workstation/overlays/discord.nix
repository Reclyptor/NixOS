_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (final: _prev: {
        # "Share Stream Audio" records the shared window's own PulseAudio sink-input,
        # so Discord needs that window's PID. It only gets one from WebRTC's X11
        # capturer; under Wayland it captures through the ScreenCast portal, which
        # reports no PID and carries no audio of its own, so the stream goes out with
        # a silent audio track. WebRTC picks its capturer off XDG_SESSION_TYPE, so
        # pinning it to x11 buys the X11 capturer. Proton games are XWayland clients
        # and stay capturable, as does `mpvx` (see overlays/mpv.nix).
        #
        # NIXOS_OZONE_WL is unset so the launcher adds no Wayland ozone flags and
        # Electron renders through XWayland like the capturer. Rendering Wayland
        # while capturing X11 left the browser process holding both display
        # connections, and that mixed mode crashed repeatedly mid-stream (native
        # SEGV/TRAP in the browser process alongside GPU-process exits); whole-app
        # X11 is the path every non-Wayland Discord user exercises.
        #
        # Stock `discord` keeps the portal path, which is the only way to share a
        # native Wayland window or a whole screen — at the cost of stream audio.
        # Discord is single-instance, so quit the running client before switching
        # launchers; otherwise the second one just focuses the first.
        discordx =
          final.runCommand "discordx-${final.discord.version}"
            {
              nativeBuildInputs = [ final.makeBinaryWrapper ];
              meta = {
                description = "Discord pinned to the X11 capture path so screen shares carry audio";
                inherit (final.discord.meta) homepage license;
                mainProgram = "discordx";
              };
            }
            ''
              makeWrapper ${final.discord}/bin/Discord $out/bin/discordx \
                --set XDG_SESSION_TYPE x11 \
                --unset NIXOS_OZONE_WL

              # MimeType is dropped so this entry never takes over discord:// links;
              # Icon=discord resolves against the discord package's own hicolor theme.
              mkdir -p $out/share/applications
              sed -e 's/^Exec=.*/Exec=discordx/' \
                  -e 's/^Name=.*/Name=Discord (X11 Capture)/' \
                  -e '/^MimeType=/d' \
                  ${final.discord}/share/applications/discord.desktop \
                  > $out/share/applications/discordx.desktop
            '';
      })
    ];
  };
}
