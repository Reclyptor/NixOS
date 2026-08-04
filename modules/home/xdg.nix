{ ... }: {
  flake.modules.homeManager.base = { lib, ... }: {
    # home-manager owns ~/.config/mimeapps.list outright and regenerates the whole
    # file from this attrset — so EVERY association has to live here or it's dropped
    # on the next rebuild. Set new "open with" defaults below rather than from a file
    # manager's GUI: a GUI change only edits the store-symlinked file and won't
    # survive a switch.
    xdg.mimeApps = {
      enable = true;

      defaultApplications = let
        zen = "zen-beta.desktop";
        signal = "signal.desktop";
        imv = "imv.desktop";
        mpvx = "mpvx.desktop";

        # Video opens in mpvx so anything playing is already shareable on Discord
        # without reopening it — mpvx renders through XWayland, which is the only
        # path Discord's capturer can see (see workstation/overlays/mpv.nix). Its
        # .desktop declares no MimeType, so this explicit default is the only thing
        # that makes it the handler; plain `mpv` stays the handler for everything
        # else. Audio is deliberately left off — there is no window to share.
        video = [
          "application/x-extension-mp4"
          "application/x-matroska"
          "video/3gp"
          "video/3gpp"
          "video/3gpp2"
          "video/avi"
          "video/divx"
          "video/dv"
          "video/fli"
          "video/flv"
          "video/mkv"
          "video/mp2t"
          "video/mp4"
          "video/mp4v-es"
          "video/mpeg"
          "video/msvideo"
          "video/ogg"
          "video/quicktime"
          "video/vnd.avi"
          "video/vnd.divx"
          "video/vnd.mpegurl"
          "video/vnd.rn-realvideo"
          "video/webm"
          "video/x-avi"
          "video/x-flc"
          "video/x-flic"
          "video/x-flv"
          "video/x-m4v"
          "video/x-matroska"
          "video/x-mpeg2"
          "video/x-mpeg3"
          "video/x-ms-afs"
          "video/x-ms-asf"
          "video/x-ms-wmv"
          "video/x-ms-wmx"
          "video/x-ms-wvxvideo"
          "video/x-msvideo"
          "video/x-ogm"
          "video/x-ogm+ogg"
          "video/x-theora"
          "video/x-theora+ogg"
        ];
      in lib.genAttrs video (_: mpvx) // {
        # Web browser
        "text/html" = zen;
        "application/xhtml+xml" = zen;
        "x-scheme-handler/http" = zen;
        "x-scheme-handler/https" = zen;
        "x-scheme-handler/about" = zen;
        "x-scheme-handler/unknown" = zen;

        # Signal
        "x-scheme-handler/sgnl" = signal;
        "x-scheme-handler/signalcaptcha" = signal;

        # Discord — was vesktop.desktop before the rebuild, but vesktop is no longer
        # installed (the `discord` package is), so this points at discord's handler.
        "x-scheme-handler/discord" = "discord.desktop";

        # Claude Code URL handler (its .desktop lives in ~/.local/share/applications)
        "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";

        # Image viewer
        "image/jpeg" = imv;
        "image/png" = imv;
        "image/webp" = imv;
      };

      # imv also registered itself as a non-default handler for these; keep that so
      # it still shows in the "Open With" list exactly as it did pre-rebuild.
      associations.added = let imv = "imv.desktop"; in {
        "image/jpeg" = imv;
        "image/png" = imv;
        "image/webp" = imv;
      };
    };
  };
}
