_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        hytale =
          let
            # Upstream publishes a version manifest at
            # https://launcher.hytale.com/version/release/launcher.json —
            # .version plus .download_url.linux.amd64.{url,sha256}. To bump, take
            # version and sha256 (base16 -> SRI via `nix hash convert`) straight
            # from the manifest; no prefetching needed. The zip is fetched flat
            # against the vendor's own hash because the CDN intermittently serves
            # divergent content (even on versioned URLs — never trust
            # -latest.zip), and unpacked in a separate deterministic step.
            version = "2026.08.11-f021bf9";
            zip = prev.fetchurl {
              url = "https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-${version}.zip";
              hash = "sha256-pgIZ1ow5PjXrqneVOUa/+n619oG2E4yn2QVSVO0kwA8=";
            };
            src =
              prev.runCommand "hytale-launcher-${version}"
                {
                  nativeBuildInputs = [ prev.unzip ];
                }
                ''
                  mkdir -p $out
                  unzip -q ${zip} -d $out
                '';
            icon = prev.fetchurl {
              url = "https://cms-a.nodecraft.com/f/133932/290x290/b0f48d6c97/icon.png";
              hash = "sha256-G1ffaG8a9CtMW3WKumrS0RDT3qfx+QXGjNkHUkWaMYM=";
            };
          in
          prev.buildFHSEnv {
            pname = "hytale";
            inherit version;

            targetPkgs =
              pkgs: with pkgs; [
                # Launcher dependencies
                libsoup_3
                gdk-pixbuf
                glib
                gtk3
                webkitgtk_4_1

                # Game dependencies
                alsa-lib
                icu
                libGL
                openssl
                udev
                libx11
                libxcursor
                libxrandr
                libxi
              ];

            runScript = "${src}/hytale-launcher";

            extraInstallCommands = ''
              mkdir -p $out/share/applications
              cat > $out/share/applications/hytale.desktop <<EOF
              [Desktop Entry]
              Type=Application
              Name=Hytale
              Comment=Hytale Launcher
              Exec=hytale
              Icon=hytale
              Categories=Game;
              Terminal=false
              EOF

              mkdir -p $out/share/icons/hicolor/256x256/apps
              ln -s ${icon} $out/share/icons/hicolor/256x256/apps/hytale.png
            '';

            meta = with prev.lib; {
              description = "Hytale Launcher";
              homepage = "https://hytale.com";
              license = licenses.unfree;
              platforms = [ "x86_64-linux" ];
            };
          };
      })
    ];
  };
}
