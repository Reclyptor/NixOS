_: {
  flake.modules.homeManager.base = { lib, ... }: {
    # home-manager owns ~/.config/mimeapps.list outright and regenerates the whole
    # file from this attrset — so EVERY association has to live here or it's dropped
    # on the next rebuild. Set new "open with" defaults below rather than from a file
    # manager's GUI: a GUI change only edits the store-symlinked file and won't
    # survive a switch.
    xdg.mimeApps = {
      enable = true;

      defaultApplications =
        let
          zen = "zen-beta.desktop";
          signal = "signal.desktop";
          imv = "imv.desktop";
          mpv = "mpv.desktop";
          mpvx = "mpvx.desktop";

          # Video opens in mpvx so anything playing is already shareable on Discord
          # without reopening it — mpvx renders through XWayland, which is the only
          # path Discord's capturer can see (see workstation/overlays/mpv.nix). Its
          # .desktop declares no MimeType, so this explicit default is the only thing
          # that makes it the handler; plain `mpv` stays the handler for everything
          # else.
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

          # Audio goes to plain mpv rather than mpvx: an audio-only file opens no
          # window, so there is nothing for Discord to capture and no reason to pay
          # for the XWayland hop. Without these explicit defaults audacity wins most
          # of them on .desktop ordering alone, which is not what a double-click on
          # an mp3 should do. List mirrors mpv's own MimeType declaration.
          audio = [
            "audio/3gpp"
            "audio/3gpp2"
            "audio/aac"
            "audio/ac3"
            "audio/aiff"
            "audio/AMR"
            "audio/amr-wb"
            "audio/dv"
            "audio/eac3"
            "audio/flac"
            "audio/m3u"
            "audio/m4a"
            "audio/mp1"
            "audio/mp2"
            "audio/mp3"
            "audio/mp4"
            "audio/mpeg"
            "audio/mpeg2"
            "audio/mpeg3"
            "audio/mpegurl"
            "audio/mpg"
            "audio/musepack"
            "audio/ogg"
            "audio/opus"
            "audio/rn-mpeg"
            "audio/scpls"
            "audio/vnd.dolby.heaac.1"
            "audio/vnd.dolby.heaac.2"
            "audio/vnd.dts"
            "audio/vnd.dts.hd"
            "audio/vnd.rn-realaudio"
            "audio/vnd.wave"
            "audio/vorbis"
            "audio/wav"
            "audio/webm"
            "audio/x-aac"
            "audio/x-adpcm"
            "audio/x-aiff"
            "audio/x-ape"
            "audio/x-m4a"
            "audio/x-matroska"
            "audio/x-mp1"
            "audio/x-mp2"
            "audio/x-mp3"
            "audio/x-mpegurl"
            "audio/x-mpg"
            "audio/x-ms-asf"
            "audio/x-ms-wma"
            "audio/x-musepack"
            "audio/x-pls"
            "audio/x-pn-au"
            "audio/x-pn-realaudio"
            "audio/x-pn-wav"
            "audio/x-pn-windows-pcm"
            "audio/x-realaudio"
            "audio/x-scpls"
            "audio/x-shorten"
            "audio/x-tta"
            "audio/x-vorbis"
            "audio/x-vorbis+ogg"
            "audio/x-wav"
            "audio/x-wavpack"
          ];
        in
        lib.genAttrs video (_: mpvx)
        // lib.genAttrs audio (_: mpv)
        // {
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

          # Image viewer. imv animates gifs through its libnsgif backend; without
          # the explicit default aseprite claims the type and a double-click drops
          # into a sprite editor.
          "image/gif" = imv;
          "image/jpeg" = imv;
          "image/png" = imv;
          "image/webp" = imv;
        };

      # imv also registered itself as a non-default handler for these; keep that so
      # it still shows in the "Open With" list exactly as it did pre-rebuild.
      associations.added =
        let
          imv = "imv.desktop";
        in
        {
          "image/gif" = imv;
          "image/jpeg" = imv;
          "image/png" = imv;
          "image/webp" = imv;
        };
    };
  };
}
