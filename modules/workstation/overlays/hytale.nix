{ ... }: {
  flake.modules.nixos.workstation = { config, pkgs, ... }: {
    nixpkgs.overlays = [
      (final: prev: {
        hytale = let
          # Upstream only publishes a mutable -latest.zip (no versioned URLs or
          # manifest as of 2026-07-03), so this pins a snapshot by date + hash.
          # When upstream pushes a new build the fetch fails loudly on hash
          # mismatch; re-pin with:
          #   nix-prefetch-url --unpack <url> && bump version date + hash
          version = "0-unstable-2026-07-03";
          src = prev.fetchzip {
            url = "https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.zip";
            hash = "sha256-7UVo52Jm2T9nWsfwgka36lPgG0mFMUKMbbE1drraR3k=";
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
  };
}
