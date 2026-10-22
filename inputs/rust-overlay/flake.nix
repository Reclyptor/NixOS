{
  description = "rust-overlay input for this flake: upstream, plus per-package build workarounds for this box.";

  # Upstream is followed by the herdr input below in ../flake.nix. herdr's
  # flake builds with `import nixpkgs { overlays = [ rust-overlay.overlays
  # .default ]; }` - its own nixpkgs evaluation that never sees this
  # flake's nixpkgs.overlays - so the workaround is composed into
  # overlays.default here, which is the only place herdr's evaluation will
  # look.

  inputs = {
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      rust-overlay,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      # Host-specific build fixes for Nixpkgs. pycairo's non-UTF-8 path test
      # needs tmpfs on this utf8only ZFS filesystem. The cherrypy gzip test
      # races on timestamps; aiohttp and httpcore2's Trio tests have tight
      # timing assumptions that fail under build load.
      #
      # Apply Python fixes to 3.14, which supplies this nixpkgs revision's
      # python3 and python3Packages aliases. Herdr imports its own nixpkgs,
      # so buildFixes must also be composed into overlays.default below.
      buildFixes =
        _final: prev:
        let
          fix = _finalPy: prevPy: {
            pycairo = prevPy.pycairo.overrideAttrs (_old: {
              TMPDIR = "/dev/shm";
            });
            cherrypy = prevPy.cherrypy.overrideAttrs (old: {
              disabledTests = (old.disabledTests or [ ]) ++ [ "testCombinedTools" ];
            });
            aiohttp = prevPy.aiohttp.overrideAttrs (old: {
              disabledTests = (old.disabledTests or [ ]) ++ [ "test_heartbeat_no_pong" ];
            });
            httpcore2 = prevPy.httpcore2.overrideAttrs (old: {
              disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
                "tests/httpcore2/test_cancellations.py::test_h2_timeout_during_request[trio]"
                "tests/httpcore2/test_cancellations.py::test_h2_timeout_during_response[trio]"
              ];
            });
          };
          python314 = prev.python314.override {
            packageOverrides = fix;
          };
          python314Packages = prev.lib.recurseIntoAttrs python314.pkgs;
        in
        {
          inherit python314 python314Packages;
          python3 = python314;
          python3Packages = prev.lib.dontRecurseIntoAttrs python314Packages;

          # libcanberra 0.30's Makefile has a parallel-install race:
          # install-gtk3moduleLTLIBRARIES relinks the GTK module against the
          # already-installed libcanberra-gtk3, but under -jN the gtk3
          # library's install can lag behind, giving
          # `ld: cannot find -lcanberra-gtk3`. Keep the build parallel and
          # serialize the install (it is cheap).
          libcanberra = prev.libcanberra.overrideAttrs (_old: {
            enableParallelInstalling = false;
          });

          # gjs: keep its non-UTF-8 filename test on tmpfs; the test sandbox's
          # utf8only ZFS filesystem rejects the fixture name.
          gjs = prev.gjs.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./patches/0001-gjs-run-non-utf8-filename-test-in-tmpdir.patch
            ];
          });

          # Azurite returns truncated HTTP error responses when Arrow runs its
          # filesystem tests concurrently. Keep CTest serial for this package;
          # leave compilation parallel and retain Arrow's full test suite.
          arrow-cpp = prev.arrow-cpp.overrideAttrs (old: {
            installCheckPhase =
              builtins.replaceStrings
                [ "ctestArgs+=(--repeat until-pass:3)" ]
                [ "ctestArgs+=(--repeat until-pass:3 --parallel 1)" ]
                old.installCheckPhase;
          });

          # Audacity 4.0's unity TU merges its extension QML models with the
          # qmlcache sources Qt 6.12 generates; those reference
          # QQmlPrivate::AOTLookupValidation::Type, which collides with
          # muse::extensions::Type while the handwritten files pull that
          # namespace in at global scope. Scope the models to their own
          # namespace instead.
          audacity = prev.audacity.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./patches/0003-audacity-scope-extensions-namespace.patch
            ];
          });

          # Tuigreet's clock test samples the wall clock before its async
          # greeter setup and requires the first render to land in the same
          # second; upstream documents the race. Accept the observed startup
          # interval instead of a single second.
          tuigreet = prev.tuigreet.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./patches/0002-tuigreet-bound-clock-check-to-rendered-frames.patch
            ];
          });

          # llama-cpp's save/load state test writes and reloads state for
          # every backend and exceeds ctest's 1500s timeout on the loaded
          # cluster nodes (it passes on the workstation). It rides into the
          # node closure via ffmpeg-full -> whisper-cpp. Drop only that test;
          # the other 47 still run.
          llama-cpp = prev.llama-cpp.overrideAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [ "test-save-load-state" ];
          });

          # libjxl's RoundtripLargeEmptyModular test allocates several
          # gigabytes and is OOM-killed on the smaller cluster nodes (it
          # passes on the workstation). Drop only that test; the other 7105
          # still run.
          libjxl = prev.libjxl.overrideAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [ "JxlTest.RoundtripLargeEmptyModular" ];
          });
        };
    in
    rust-overlay
    // {
      overlays = rust-overlay.overlays // {
        inherit buildFixes;
        default = lib.composeExtensions rust-overlay.overlays.default buildFixes;
      };
    };
}
