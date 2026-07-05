{ ... }: {
  # Zen isn't in nixpkgs, so we package the official upstream binary ourselves
  # rather than depend on a third-party flake. Same trust model nixpkgs uses for
  # google-chrome/discord/etc: fetch the vendor's release tarball pinned by hash,
  # then autoPatchelf + GApps-wrap it like Firefox.
  #
  # To bump: set `version` to the new tag from
  # https://github.com/zen-browser/desktop/releases, set `hash` to
  # lib.fakeHash, rebuild, and paste the hash Nix reports back.
  flake.modules.nixos.workstation = { ... }: {
    nixpkgs.overlays = [
      (final: prev: {
        zen-browser = let
          version = "1.21.5b";
          src = prev.fetchzip {
            url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-x86_64.tar.xz";
            hash = "sha256-2N28S8cpB9isXM8+DQpypwclS1oGG6DLRFP3spxtOjA=";
          };
        in prev.stdenv.mkDerivation {
          pname = "zen-browser";
          inherit version src;

          nativeBuildInputs = [
            prev.wrapGAppsHook3
            prev.autoPatchelfHook
            # Firefox uses relrhack; its ELFs need patchelf's --no-clobber-old-sections.
            prev.patchelfUnstable
            prev.copyDesktopItems
          ];

          buildInputs = [
            prev.gtk3
            prev.adwaita-icon-theme
            prev.alsa-lib
            prev.dbus-glib
            prev.libXtst
            prev.ffmpeg_7
          ];

          runtimeDependencies = [
            prev.curl
            prev.libva.out
            prev.pciutils
            prev.libGL
          ];

          appendRunpaths = [
            "${prev.libGL}/lib"
            "${prev.pipewire}/lib"
            # Firefox's cubeb audio backend dlopens libpulse.so.0 by soname from
            # libxul.so — it's not a DT_NEEDED link, so autoPatchelf can't discover
            # it, and runtimeDependencies only patches the launcher, not libxul. It
            # must be on libxul's own RUNPATH (which glibc uses for its dlopens), so
            # append it here. Without it, video plays silently on our PipeWire
            # (pulse.enable) system, the socket cubeb routes audio through.
            "${prev.libpulseaudio}/lib"
          ];

          patchelfFlags = [ "--no-clobber-old-sections" ];

          desktopItems = [
            (prev.makeDesktopItem {
              name = "zen-beta";
              desktopName = "Zen Browser";
              genericName = "Web Browser";
              exec = "zen-beta %U";
              icon = "zen-beta";
              startupWMClass = "zen-beta";
              startupNotify = true;
              terminal = false;
              categories = [ "Network" "WebBrowser" ];
              keywords = [ "Internet" "WWW" "Browser" "Web" "Explorer" ];
              mimeTypes = [
                "text/html"
                "text/xml"
                "application/xhtml+xml"
                "x-scheme-handler/http"
                "x-scheme-handler/https"
                "application/x-xpinstall"
                "application/pdf"
                "application/json"
              ];
              actions = {
                new-window = {
                  name = "Open a New Window";
                  exec = "zen-beta --new-window %U";
                };
                new-private-window = {
                  name = "Open a New Private Window";
                  exec = "zen-beta --private-window %U";
                };
                profile-manager = {
                  name = "Open the Profile Manager";
                  exec = "zen-beta --ProfileManager";
                };
              };
            })
          ];

          installPhase = ''
            runHook preInstall

            mkdir -p $out/lib/zen
            cp -r $src/* $out/lib/zen

            mkdir -p $out/bin
            ln -s $out/lib/zen/zen $out/bin/zen-beta

            for size in 16 32 48 64 128; do
              install -Dm644 \
                $src/browser/chrome/icons/default/default''${size}.png \
                $out/share/icons/hicolor/''${size}x''${size}/apps/zen-beta.png
            done

            runHook postInstall
          '';

          # Give the toolkit its codecs and stamp the Wayland app_id / X11 class so
          # it matches the desktop entry's StartupWMClass (and Hyprland rules).
          preFixup = ''
            gappsWrapperArgs+=(
              --prefix LD_LIBRARY_PATH : "${prev.lib.makeLibraryPath [ prev.ffmpeg_7 ]}"
              --add-flags "--name=zen-beta"
              --add-flags "--class=zen-beta"
              # Pin the profile across Nix rebuilds. Firefox/Zen tie their "dedicated
              # profile per install" to a hash of the binary's path — which changes
              # on every store-path change — so each rebuild would otherwise spawn a
              # fresh, empty profile and orphan your bookmarks/workspaces in the old
              # one. MOZ_LEGACY_PROFILES makes Zen honor the profiles.ini default
              # regardless of install path; MOZ_ALLOW_DOWNGRADE stops the version
              # guard from blocking when the path moves.
              --set MOZ_LEGACY_PROFILES 1
              --set MOZ_ALLOW_DOWNGRADE 1
            )
          '';

          meta = with prev.lib; {
            description = "Experience tranquillity while browsing the web without being tracked";
            homepage = "https://zen-browser.app";
            license = licenses.mpl20;
            sourceProvenance = [ sourceTypes.binaryNativeCode ];
            platforms = [ "x86_64-linux" ];
            mainProgram = "zen-beta";
          };
        };
      })
    ];
  };
}
