{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      hytale = let
        version = "latest";
        src = prev.fetchzip {
          url = "https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.zip";
          hash = "sha256-ZW0JLjOjz0mUXN+wSWvAsRbgzb3DYdpMHkHHp4OGrvM=";
        };
        icon = prev.fetchurl {
          url = "https://cms-a.nodecraft.com/f/133932/290x290/b0f48d6c97/icon.png";
          hash = "sha256-G1ffaG8a9CtMW3WKumrS0RDT3qfx+QXGjNkHUkWaMYM=";
        };
      in prev.buildFHSEnv {
        pname = "hytale";
        inherit version;

        targetPkgs = pkgs: with pkgs; [
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
}
