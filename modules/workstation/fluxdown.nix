_: {
  # FluxDown (github.com/zerx-lab/FluxDown) — a multi-protocol download manager:
  # HTTP/HTTPS, FTP, BitTorrent and magnet, eD2K, HLS, DASH. AGPL-3.0.
  #
  # Not one binary. A shared Rust engine is driven by a download daemon
  # (fluxdownd) and a gateway process (fluxdown-agent); the desktop chain is
  # fluxdown-desktop -> fluxdown-agent -> fluxdownd, plus fluxdown_nmh, the
  # native-messaging host the browser extension speaks to. The UI is GPUI, Zed's
  # GPU renderer, on wgpu/Vulkan — not Tauri, Electron or webkitgtk; GTK3 is here
  # only for the tray icon.
  #
  # See SPEC/fluxdown-desktop.md for the reasoning behind the version/updater
  # entanglement and why the headless server variant is out of scope.
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    let
      # What the binaries load by name at runtime rather than record as NEEDED,
      # measured from the built artifact rather than taken from upstream's deb
      # control block — that list is a conservative superset and names several
      # libraries nothing here touches.
      #
      # wgpu compiles both its Vulkan and its GLES backend (wgpu_hal::vulkan and
      # wgpu_hal::gles are both present), so both paths need to resolve: libvulkan
      # through the loader, libEGL through libglvnd. libwayland-client and
      # libwayland-egl are dlopened too, for the Wayland session.
      #
      # Not here, and deliberately: fontconfig and freetype turn out to be linked
      # statically into the binary, libX11 is unused (XCB is the only X path and
      # it is recorded as NEEDED), and neither libasound nor libdbus appears
      # anywhere in any of the binaries — zbus speaks the D-Bus protocol itself.
      dlopenLibraries = with pkgs; [
        vulkan-loader
        libglvnd
        wayland
      ];

      fluxdown = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
        pname = "fluxdown";
        version = "0.5.5";

        # An umbrella tag. The tag namespace also carries per-component tags
        # (cli-*, server-*, mobile-*, website-*) and only the umbrella vX.Y.Z ones
        # are annotated objects, so look for v<semver> specifically when bumping.
        src = pkgs.fetchFromGitHub {
          owner = "zerx-lab";
          repo = "FluxDown";
          tag = "v${finalAttrs.version}";
          hash = "sha256-/G8uotcIfuU9x8cDSXS1/0TPwcV0lDkP1X9E6n0hI0g=";
        };

        # One hash covers all six pinned git dependencies — longbridge/gpui-fast
        # alone supplies some 23 lock entries — because fetchCargoVendor fetches
        # git sources itself. No cargoLock.outputHashes needed.
        cargoHash = "sha256-0CNebDl07JUocFxSJr1iZ9oeveRDxmV56P5AJKq9coY=";

        # Without this the store install classifies as LinuxPortable and the
        # in-place updater tries to overwrite /nix/store. The patch header has
        # the full reasoning.
        patches = [ ./fluxdown-managed-package.patch ];

        nativeBuildInputs = with pkgs; [
          pkg-config
          cmake # aws-lc-sys
          clang
          rustPlatform.bindgenHook
          makeWrapper
          desktop-file-utils # for the validation below
        ];

        # No xdotool: upstream's deb depends on libxdo3, but nothing in Cargo.lock
        # links it and it appears in no binary's NEEDED list — a leftover from the
        # Flutter-desktop era.
        buildInputs = with pkgs; [
          libxkbcommon
          libx11
          libxcb
          wayland
          vulkan-loader
          fontconfig
          freetype
          gtk3
          libayatana-appindicator
          glib
          zstd
        ];

        # Upstream's own release command (release.yml:947-949) plus the CLI.
        cargoBuildFlags = [
          "-p"
          "fluxdown_ui_app"
          "-p"
          "fluxdown_agent"
          "-p"
          "fluxdown_daemon"
          "-p"
          "fluxdown_nmh"
          "-p"
          "fluxdown_cli"
        ];
        buildFeatures = [ "fluxdown_agent/desktop" ];

        # The product version, read through option_env! by fluxdown_protocol,
        # fluxdown_agent and fluxdown_nmh. Leave it unset and they each fall back
        # somewhere different — protocol to its own crate version, the engine to
        # a pubspec.yaml that still says 0.1.44 — so all of them need it. Setting
        # it also marks the build "official", which is what the patch above
        # compensates for.
        env.FLUXDOWN_APP_VERSION = finalAttrs.version;

        # Upstream's CI runs `cargo nextest` with full network access and the
        # tests were not audited for outbound calls, so they are not a meaningful
        # gate in a sandbox. Stated rather than silently omitted.
        doCheck = false;

        postInstall = ''
          install -Dm644 packaging/linux/com.fluxdown.app.desktop \
            -t $out/share/applications
          install -Dm644 assets/logo/fluxdown_logo.png \
            $out/share/icons/hicolor/256x256/apps/com.fluxdown.app.png
          desktop-file-validate $out/share/applications/com.fluxdown.app.desktop
        '';

        # Every binary finds its siblings relative to current_exe — the desktop
        # app looks for fluxdown-agent, the agent for fluxdownd and fluxdown_nmh.
        # makeWrapper keeps them siblings (the real binaries stay in the same
        # directory as .name-wrapped), so this is safe; splitting them across
        # outputs would not be.
        #
        # ffmpeg and yt-dlp are on PATH deliberately. Without them the engine
        # downloads third-party static builds into its data directory at runtime;
        # resolve_ffmpeg falls back to PATH, so providing them stops that.
        postFixup = ''
          for bin in fluxdown-desktop fluxdown-agent fluxdownd fluxdown; do
            wrapProgram $out/bin/$bin \
              --set-default FLUXDOWN_INSTALL_SOURCE nix \
              --prefix PATH : ${
                lib.makeBinPath [
                  pkgs.ffmpeg
                  pkgs.yt-dlp
                ]
              } \
              --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath dlopenLibraries}:${pkgs.addDriverRunpath.driverLink}/lib
          done
        '';

        meta = {
          description = "Multi-protocol download manager with a GPUI desktop app";
          homepage = "https://github.com/zerx-lab/FluxDown";
          license = lib.licenses.agpl3Only;
          platforms = [ "x86_64-linux" ];
          mainProgram = "fluxdown-desktop";
        };
      });
    in
    {
      environment.systemPackages = [ fluxdown ];
    };
}
