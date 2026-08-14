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
        zen-browser =
          let
            version = "1.21.5b";
            src = prev.fetchzip {
              url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-x86_64.tar.xz";
              hash = "sha256-2N28S8cpB9isXM8+DQpypwclS1oGG6DLRFP3spxtOjA=";
            };
            # Enterprise policy shipped with the app. We already make Zen the system
            # default declaratively (modules/home/xdg.nix), so switch off its startup
            # default-browser check: the check never matches our desktop-file name
            # under Nix, and its "Set as default" button can't persist anyway because
            # mimeapps.list is a read-only store symlink.
            policiesJson = prev.writeText "zen-policies.json" (
              builtins.toJSON { policies.DontCheckDefaultBrowser = true; }
            );

            # Ship a default pref via Firefox's autoconfig (.cfg) mechanism — the one
            # reliable way to set an arbitrary pref from a hand-rolled build. Crunchyroll
            # (and other Widevine sites) throw KAT-6005 when you scrub the timeline: a
            # MOZ_LOG capture showed the seek flushes the decoder and the post-seek frame
            # burst exhausts Gecko's CDM video shmem pool, so the CDM returns rv=1 and the
            # MediaKeySession is torn down. Value matters in BOTH directions: 6 (default)
            # is too few and fails on seek; 24 regressed to dying within seconds
            # (reproduced via A/B/A: 12 works, 24 breaks, 12 works — the exact mechanism
            # was NOT captured, so don't trust any "why" beyond that). 12 is the
            # empirically confirmed sweet spot — don't raise it.
            autoconfigCfg = prev.writeText "zen.cfg" ''
              // Managed by Nix (modules/workstation/overlays/zen-browser.nix). First line
              // is intentionally a comment — Firefox skips it.
              defaultPref("media.eme.chromium-api.video-shmems", 12);
            '';
            autoconfigLoader = prev.writeText "local-settings.js" ''
              pref("general.config.filename", "zen.cfg");
              pref("general.config.obscure_value", 0);
            '';
          in
          prev.stdenv.mkDerivation {
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
              # Same story for WebAuthn/U2F: libxul dlopens libudev.so.1 to enumerate
              # the FIDO HID device, so without it on the RUNPATH a YubiKey can't be
              # used for security-key logins. systemdLibs is the minimal libudev.
              "${prev.systemdLibs}/lib"
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
                categories = [
                  "Network"
                  "WebBrowser"
                ];
                keywords = [
                  "Internet"
                  "WWW"
                  "Browser"
                  "Web"
                  "Explorer"
                ];
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
              # Store-copied dirs are read-only; make the tree writable so we can drop
              # our autoconfig files into Zen's own defaults/pref/.
              chmod -R u+w $out/lib/zen

              mkdir -p $out/bin
              ln -s $out/lib/zen/zen $out/bin/zen-beta

              for size in 16 32 48 64 128; do
                install -Dm644 \
                  $src/browser/chrome/icons/default/default''${size}.png \
                  $out/share/icons/hicolor/''${size}x''${size}/apps/zen-beta.png
              done

              install -Dm644 ${policiesJson} $out/lib/zen/distribution/policies.json

              install -Dm644 ${autoconfigCfg} $out/lib/zen/zen.cfg
              install -Dm644 ${autoconfigLoader} $out/lib/zen/defaults/pref/local-settings.js

              runHook postInstall
            '';

            # Give the toolkit its codecs and stamp the Wayland app_id / X11 class so
            # it matches the desktop entry's StartupWMClass (and Hyprland rules).
            preFixup = ''
              gappsWrapperArgs+=(
                # libxul — in the content, GPU, RDD and CDM plugin-container child
                # processes — dlopens the graphics stack by soname for its zero-copy
                # video path: libgbm.so.1 + libdrm.so.2 (BlitYCbCrImageToDMABuf),
                # libva.so.2 / libva-drm.so.2 (VA-API) and libvulkan.so.1 (WebRender).
                # None are DT_NEEDED. LD_LIBRARY_PATH is inherited by every child and
                # resolves the stack's chained dlopens (libva->driver, libgbm->backend),
                # which is why upstream wrapFirefox delivers them this way rather than via
                # per-ELF RUNPATH. Without them the GPU image allocation fails on every
                # decoded frame and the software fallback collapses on seek/resume of DRM
                # video (Crunchyroll KAT-6005). libGL is glvnd (libGL/libEGL).
                --prefix LD_LIBRARY_PATH : "${
                  prev.lib.makeLibraryPath [
                    prev.ffmpeg_7
                    prev.libgbm
                    prev.libva.out
                    prev.libdrm
                    prev.vulkan-loader
                    prev.libGL
                  ]
                }"
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
