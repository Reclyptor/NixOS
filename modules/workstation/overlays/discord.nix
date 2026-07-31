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
        discord = prev.discord.overrideAttrs (old: {
          postFixup = (old.postFixup or "") + ''
            rm $out/bin/Discord $out/bin/discord
            makeWrapper $out/opt/Discord/Discord $out/bin/Discord \
              --set XDG_SESSION_TYPE x11
            ln -s Discord $out/bin/discord
          '';
        });
      })
    ];
  };
}
