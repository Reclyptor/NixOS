{ ... }: {
  flake.modules.nixos.workstation = { ... }: {
    nixpkgs.overlays = [
      (final: prev: {
        # "Share Stream Audio" records the shared window's own PulseAudio sink-input,
        # so Discord needs that window's PID. It only gets one from WebRTC's X11
        # capturer; under Wayland it captures through the ScreenCast portal, which
        # reports no PID and carries no audio of its own, so the stream goes out with
        # a silent audio track. WebRTC picks its capturer off XDG_SESSION_TYPE while
        # the render path keys off NIXOS_OZONE_WL/WAYLAND_DISPLAY, so pinning only
        # XDG_SESSION_TYPE buys the X11 capturer without giving up native Wayland
        # rendering. Proton games are XWayland clients and stay capturable, as does
        # `mpvx` (see overlays/mpv.nix).
        #
        # Stock `discord` keeps the portal path, which is the only way to share a
        # native Wayland window or a whole screen — at the cost of stream audio.
        # Discord is single-instance, so quit the running client before switching
        # launchers; otherwise the second one just focuses the first.
        discordx = final.runCommand "discordx-${final.discord.version}" {
          nativeBuildInputs = [ final.makeBinaryWrapper ];
          meta = {
            description = "Discord pinned to the X11 capture path so screen shares carry audio";
            inherit (final.discord.meta) homepage license;
            mainProgram = "discordx";
          };
        } ''
          makeWrapper ${final.discord}/bin/Discord $out/bin/discordx \
            --set XDG_SESSION_TYPE x11

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
