{ ... }: {
  flake.modules.nixos.workstation = { ... }: {
    nixpkgs.overlays = [
      (final: prev: {
        # 0.47.1's config watcher (kitten __watch_conf__) leaks inotify
        # watches until the per-user budget is exhausted; 0.47.4 fixes it.
        kitty = prev.kitty.overrideAttrs (old: rec {
          version = "0.47.4";

          src = prev.fetchFromGitHub {
            owner = "kovidgoyal";
            repo = "kitty";
            tag = "v${version}";
            hash = "sha256-UDuWbWg7HiyJ4q/fVLLD+ZFmK74H2A2HRRwPoyGyGtU=";
          };

          goModules = (prev.buildGo126Module {
            pname = "kitty-go-modules";
            inherit src version;
            vendorHash = "sha256-o9S5KFT+9DRQ+OcZ5Wh8ZwtWE/19DYR810zCk+yUIr4=";
          }).goModules;

          # go.mod pins `toolchain go1.26.4`, but nixpkgs ships go 1.26.3 and the
          # sandbox can't fetch toolchains. Use the local one; it satisfies the
          # `go 1.26.0` minimum.
          preBuild = (old.preBuild or "") + ''
            export GOTOOLCHAIN=local
          '';
        });
      })
    ];
  };
}
