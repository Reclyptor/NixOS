{ ... }: {
  flake.modules.nixos.workstation = { ... }: {
    nixpkgs.overlays = [
      (final: prev: {
        # "Share Stream Audio" records the shared window's own PulseAudio
        # sink-input, so Discord needs that window's PID. It only gets one from
        # WebRTC's X11 capturer; under Wayland it captures through the
        # ScreenCast portal, which reports no PID and carries no audio of its
        # own, so the stream goes out with a silent audio track. WebRTC picks
        # the capturer off XDG_SESSION_TYPE, so overriding just that for
        # Discord restores the X11 path while the client keeps rendering
        # natively on Wayland. Proton games are XWayland clients, so they stay
        # capturable.
        #
        # The X11 capturer only enumerates X11 windows, so `discord-wayland`
        # keeps the portal path available for sharing native Wayland windows or
        # a whole screen — at the cost of stream audio. Discord is
        # single-instance, so quit the running one before switching launchers.
        discord = prev.discord.overrideAttrs (old: {
          postFixup = (old.postFixup or "") + ''
            rm $out/bin/Discord $out/bin/discord
            makeWrapper $out/opt/Discord/Discord $out/bin/Discord \
              --set XDG_SESSION_TYPE x11
            ln -s Discord $out/bin/discord

            makeWrapper $out/opt/Discord/Discord $out/bin/discord-wayland \
              --set XDG_SESSION_TYPE wayland

            # share/applications is a symlink to the makeDesktopItem output, so
            # replace it with a real directory we can add an entry to.
            entries=$(readlink -f $out/share/applications)
            rm $out/share/applications
            mkdir -p $out/share/applications
            cp $entries/discord.desktop $out/share/applications/
            sed -e 's/^Exec=.*/Exec=discord-wayland/' \
                -e 's/^Name=.*/Name=Discord (Wayland Capture)/' \
                -e '/^MimeType=/d' \
                $entries/discord.desktop \
                > $out/share/applications/discord-wayland.desktop
          '';
        });
      })
    ];
  };
}
