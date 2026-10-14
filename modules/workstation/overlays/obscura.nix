_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        # nixpkgs pins 0.2.0, which predates the CDP DOM.resolveNode fix
        # (upstream #956) that Playwright MCP's element refs depend on; without
        # it every click by ref fails with "Ref ... not found". The fix shipped
        # in 0.2.3.
        #
        # Built from source with the `render` and `stealth` features, as
        # nixpkgs master does. `render` pulls in btls-sys, which builds its
        # bundled BoringSSL with CMake and bindgen, and `git init`s the
        # checkout.
        #
        # Refresh: bump `version`, take the src hash from
        #   nix store prefetch-file --json --unpack <tag tarball> | jq -r .hash
        # read the `v8` crate version out of the tag's Cargo.lock for the
        # librusty_v8 archive (nix-prefetch-url its release asset), then build
        # once with cargoHash set to lib.fakeHash to learn the vendor hash.
        obscura = prev.obscura.overrideAttrs (
          old:
          let
            version = "0.2.4";
            src = prev.fetchFromGitHub {
              owner = "h4ckf0r0day";
              repo = "obscura";
              rev = "v${version}";
              hash = "sha256-thpUbGHwO2oU1kaIlrSp1RBonITVjyS8xocmlAZYpJ0=";
            };
            # deno_core turns on the v8 crate's `simdutf` feature, which links
            # against the `_simdutf` flavor of the prebuilt archive.
            v8Version = "150.4.0";
            librusty_v8 = old.passthru.librusty_v8.overrideAttrs {
              name = "librusty_v8-${v8Version}";
              src = prev.fetchurl {
                url = "https://github.com/denoland/rusty_v8/releases/download/v${v8Version}/librusty_v8_simdutf_release_x86_64-unknown-linux-gnu.a.gz";
                sha256 = "0xml6268gjs2pj7xf50gx3ly337c63j5l724b9hgrwfi235651zl";
              };
            };
          in
          {
            inherit version src;
            # buildRustPackage consumes cargoHash when it is called, before
            # overrideAttrs sees anything, so the vendor derivation itself is
            # replaced.
            cargoDeps = prev.rustPlatform.fetchCargoVendor {
              inherit src version;
              pname = "obscura";
              hash = "sha256-5nBy/hJgNpun7bhKuTd0sBBwDUcbnBkvSMh+6GgIsIo=";
            };

            # Same for `buildFeatures`, which it turns into this up front.
            cargoBuildFeatures = [
              "render"
              "stealth"
            ];

            nativeBuildInputs = old.nativeBuildInputs ++ [
              prev.rustPlatform.bindgenHook
              prev.cmake
              prev.perl
              prev.git
            ];

            env = old.env // {
              RUSTY_V8_ARCHIVE = librusty_v8;
              OBSCURA_VERSION = version;
            };

            passthru = old.passthru // {
              inherit librusty_v8;
            };

            meta = old.meta // {
              platforms = [ "x86_64-linux" ];
            };
          }
        );
      })
    ];
  };
}
