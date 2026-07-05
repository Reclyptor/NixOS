{ ... }: {
  flake.modules.homeManager.base = { ... }: {
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
      in {
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
