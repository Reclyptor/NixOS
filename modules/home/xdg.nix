{ ... }: {
  flake.modules.homeManager.base = { ... }: {
    # Route link-opening (xdg-open and any app handing off a URL) to Zen.
    xdg.mimeApps = {
      enable = true;
      defaultApplications = let zen = "zen-beta.desktop"; in {
        "text/html" = zen;
        "application/xhtml+xml" = zen;
        "x-scheme-handler/http" = zen;
        "x-scheme-handler/https" = zen;
        "x-scheme-handler/about" = zen;
        "x-scheme-handler/unknown" = zen;
      };
    };
  };
}
