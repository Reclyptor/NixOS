# Shared build for the Storytold craft suite (github.com/storytold): thirteen
# clean-room, Apache-2.0/MIT Rust rewrites of Adobe, Microsoft Office, Avid,
# Autodesk and Figma applications, each a cargo workspace of the same shape —
# `crates/*` plus `apps/<name>`, `apps/<name>-cli` and `apps/<name>-web`, with a
# validated freedesktop set under `packaging/linux/`.
#
# ArtCraft is upstream's name for the whole suite and for the engine its first
# seven apps, the Adobe equivalents, are built on; the six office, audio, CAD and
# interface-design apps that followed are the same workspace shape and build
# identically.
#
# The leading underscore keeps import-tree from importing this file: it is a
# plain function, not a flake-parts module. Same mechanism that lets
# overlays/dsh-skin/_runtime/ hold assets rather than modules.
#
# Each app gets its own module beside this one. They differ only in pin,
# version and native dependencies, so the derivation itself lives here once.
{ lib, pkgs }:

{
  # Upstream repo name, which is also the binary and the cargo package.
  pname,
  version,
  # Release tag. These repos take commits several times a day, so the pin is a
  # tag rather than a branch — see SPEC/storytold-artcraft-suite.md.
  rev ? "v${version}",
  hash,
  cargoHash,
  # Publication date of `rev`, substituted into the AppStream metainfo below.
  releaseDate,
  # Freedesktop Name= / Comment=, for the module's own `meta`.
  description,
  # Build scripts that need more than rustc and cc. Kept per-app rather than
  # given to all thirteen: only the four that pull alsa-sys (deckcraft,
  # effectcraft, filmcraft, soundcraft) need any.
  extraNativeBuildInputs ? [ ],
  extraBuildInputs ? [ ],
  # Cargo features. Off by default upstream so distributors can choose; where
  # the official build turns one on, the app module says so.
  buildFeatures ? [ ],
  # Compile-time environment. Five apps read a build provenance through
  # option_env! — photocraft, wordcraft, deckcraft, cadcraft and figcraft — and
  # are given only the variables they actually read. The other option_env! reads
  # in the suite are ones upstream's own release builds leave unset (pdfcraft's
  # local build label, figcraft's collaboration server), so those apps pass
  # nothing, and this stays an empty attrset, which is what mkDerivation would
  # default to anyway.
  extraEnv ? { },
  # Patches applied to a dependency's vendored sources, as
  # [ { crate = "<name>-<version>"; patch = ./x.patch; } ]. Only pdfcraft needs
  # one, to get past a rustc codegen bug in a transitive dependency — see
  # SPEC/storytold-artcraft-suite.md. Empty for the other twelve, which then take
  # the vendor tree buildRustPackage builds for itself, untouched.
  vendorPatches ? [ ],
  # The storytold/craft-fonts commit this app's release workflow embeds, for
  # the eleven apps whose font crate reads CRAFT_FONTS_DIR. Null for the two
  # that do not (effectcraft, soundcraft), which then build exactly as without
  # it.
  craftFontsRev ? null,
  # The storytold/craft-i18n commit named by the repo's craft-i18n.rev, for apps
  # whose translations moved out of the repo into that catalog. Null for apps
  # without the file. The build checks it against the file, so a bump that
  # forgets to move it fails instead of embedding stale catalogs.
  craftI18nRev ? null,
  # Whether `<app>-cli` ships a `man-and-completions` example, which upstream's
  # package.sh builds and runs to install its man pages and bash, zsh and fish
  # completions.
  cliDocs ? false,
}:

let
  appId = "ai.storyteller.${pname}";

  # One hash per craft-fonts commit, kept here rather than in each app module
  # because the release workflows share two commits between eleven apps.
  craftFontsHashes = {
    "b076417b5880bd4154bd22f00695b1d28c6bea83" = "sha256-jZ3VBAJDofB6RvsS7GGV5lLT4xiShIjpz5XHBCD2oUc=";
    "37827adc41fd165f9a9234ac40f94dbad353aa69" = "sha256-BfFMLP2LLrKS246gGpj26ECVRa5/Ggzkesf0OBrfGu8=";
  };

  # Japanese, Chinese, Arabic and Thai faces under OFL-1.1, which a font crate's
  # build.rs compiles in from fonts/manifest.txt. Upstream's release builds
  # always embed them; without them those scripts fall back to whatever the
  # system happens to have. The build script reads only this checkout.
  craftFonts = lib.mapNullable (
    fontsRev:
    pkgs.fetchFromGitHub {
      owner = "storytold";
      repo = "craft-fonts";
      rev = fontsRev;
      hash =
        craftFontsHashes.${fontsRev}
          or (throw "_artcraft.nix: no hash for craft-fonts ${fontsRev}; add it to craftFontsHashes");
    }
  ) craftFontsRev;

  craftI18nHashes = {
    "9205108cfdced5177706264038848b68b2422d2b" = "sha256-aHgtGkE5VVjsGiD3lZUQzn/1fOGlUxN5Mq4WCer9PGY=";
  };

  # Translation catalogs a ui crate's build.rs embeds. Without them the build
  # still succeeds, but the app is English only.
  craftI18n = lib.mapNullable (
    i18nRev:
    pkgs.fetchFromGitHub {
      owner = "storytold";
      repo = "craft-i18n";
      rev = i18nRev;
      hash =
        craftI18nHashes.${i18nRev}
          or (throw "_artcraft.nix: no hash for craft-i18n ${i18nRev}; add it to craftI18nHashes");
    }
  ) craftI18nRev;

  src = pkgs.fetchFromGitHub {
    owner = "storytold";
    repo = pname;
    inherit rev hash;
  };

  # The same vendored dependency tree buildRustPackage would build from
  # cargoHash, named here so a dependency inside it can be patched: the fetch is
  # a fixed-output derivation, so its result cannot be modified in place and the
  # patch has to land in a copy. Only reached when vendorPatches is non-empty.
  vendor = pkgs.rustPlatform.fetchCargoVendor {
    inherit pname version src;
    hash = cargoHash;
  };

  patchedVendor =
    pkgs.runCommand "${pname}-${version}-vendor-patched"
      {
        nativeBuildInputs = [ pkgs.jq ];
      }
      (
        ''
          cp -R --no-preserve=mode,ownership ${vendor} $out
        ''
        + lib.concatMapStrings (p: ''
          # fetchCargoVendor groups sources by where they came from — registry
          # crates land under source-registry-<n>/ — so resolve the crate by
          # name instead of assuming a layout, and refuse to guess if that is
          # not exactly one directory.
          crate=$(find $out -mindepth 2 -maxdepth 2 -type d -name '${p.crate}')
          if [ "$(printf '%s' "$crate" | grep -c .)" -ne 1 ]; then
            echo "vendorPatches: ${p.crate} is not one directory in the vendor tree" >&2
            exit 1
          fi

          # Cargo verifies a vendored crate against the checksums it ships, but
          # fetchCargoVendor lists none of its files — it writes `"files": {}`,
          # leaving only the package hash — so a patched file needs no
          # re-hashing. Assert that rather than assume it: if nixpkgs starts
          # listing them, the entry for every patched file has to be recomputed
          # here or cargo will reject the tree.
          if [ "$(jq '.files | length' "$crate/.cargo-checksum.json")" != 0 ]; then
            echo "vendorPatches: ${p.crate} ships per-file checksums, which this does not update" >&2
            exit 1
          fi

          # --fuzz=0: a patch that no longer applies exactly, because the pin
          # moved under it, should fail rather than land somewhere plausible.
          patch -p1 --fuzz=0 -d "$crate" < ${p.patch}
        '') vendorPatches
      );

  # winit and wgpu dlopen their windowing and GPU libraries, so none of these is
  # an ELF NEEDED entry and nothing in the closure refers to them — the wrapper
  # below is what makes them resolvable at all. The set is upstream's own, from
  # packaging/linux/nfpm.yaml, and photocraft re-checks it at start-up in
  # apps/photocraft/src/linux_libs.rs.
  #
  # That start-up check is explicitly inconclusive on NixOS (it reads an
  # ldconfig cache we do not have, then warns and continues), and the other
  # twelve apps ship no equivalent at all, so a library missing here does not
  # produce a friendly "install this package" message — it panics inside
  # xkbcommon-dl before the window opens. vectorcraft borrows the same probe in
  # apps/vectorcraft/src/xwayland.rs, but only to decide whether a pen may open
  # the window through Xwayland; it also searches LD_LIBRARY_PATH, so this
  # wrapper satisfies it.
  #
  # Printing, in every app that offers it (craft-libs' craft-print, and
  # pdfcraft's own print crate), runs CUPS's lp, lpstat and lpoptions from PATH;
  # without them the Print dialog still offers Save as PDF. They are not wrapped
  # in: this host runs no CUPS daemon for them to talk to, and enabling
  # services.printing puts them on PATH.
  runtimeLibraries = [
    pkgs.libxkbcommon # libxkbcommon.so.0 and libxkbcommon-x11.so.0
    pkgs.libx11 # libX11.so.6 and libX11-xcb.so.1
    pkgs.libxcb
    pkgs.libxcursor
    pkgs.libxi
    pkgs.wayland # libwayland-client.so.0
    pkgs.vulkan-loader # wgpu's first choice; finds its ICDs under /run/opengl-driver
    pkgs.libGL # libEGL.so.1, wgpu's fallback
    # winit asks for RandR over x11rb rather than through libXrandr, but every
    # app's nfpm.yaml lists it, so the wrapper carries upstream's full set.
    pkgs.libxrandr
  ];
in
pkgs.rustPlatform.buildRustPackage {
  inherit
    pname
    version
    src
    cargoHash
    buildFeatures
    ;

  # Null leaves buildRustPackage to build the vendor tree from cargoHash, which
  # is what the twelve unpatched apps want: passing one explicitly changes the
  # derivation even when the contents are identical, and would rebuild all of
  # them to no purpose.
  cargoDeps = if vendorPatches == [ ] then null else patchedVendor;

  nativeBuildInputs = [
    pkgs.makeWrapper
  ]
  ++ lib.optional cliDocs pkgs.installShellFiles
  ++ extraNativeBuildInputs;
  buildInputs = extraBuildInputs;

  # CRAFT_FONTS_REQUIRED and CRAFT_I18N_REQUIRED, as in upstream's release
  # workflows, turn a checkout the build script cannot use into an error rather
  # than a silent build without fonts or translations.
  env =
    extraEnv
    // lib.optionalAttrs (craftFonts != null) {
      CRAFT_FONTS_DIR = "${craftFonts}";
      CRAFT_FONTS_REQUIRED = "1";
    }
    // lib.optionalAttrs (craftI18n != null) {
      CRAFT_I18N_DIR = "${craftI18n}";
      CRAFT_I18N_REQUIRED = "1";
    };

  # The rev has to be spelled out rather than read from the source, which would
  # be import-from-derivation; this keeps the two from drifting apart.
  postPatch = lib.optionalString (craftI18nRev != null) ''
    if [ "$(tr -d '[:space:]' < craft-i18n.rev)" != ${lib.escapeShellArg craftI18nRev} ]; then
      echo "craftI18nRev does not match craft-i18n.rev ($(cat craft-i18n.rev))" >&2
      exit 1
    fi
  '';

  # Since the 2026-10-28 releases every app patches the whole storytold egui
  # fork family in, including members it never uses (egui_demo_lib and others),
  # which Cargo.lock lists as [[patch.unused]] and the vendor tree therefore
  # lacks. Offline cargo then fails on "patch location does not contain
  # packages". preConfigure, not postPatch: a derivation's own postPatch runs
  # before cargoSetupPostPatchHook compares Cargo.lock with the vendored copy.
  preConfigure = ''
    ${pkgs.python3.interpreter} -I ${./strip-unused-patches.py}
  '';

  # What upstream's packaging/linux/package.sh builds. Deliberately not the
  # workspace default members: those also carry `<app>-web`, a wasm32 target,
  # and `xtask`, build tooling — neither belongs in a system closure.
  #
  # --locked is ours. The build hook passes --offline, which lets a drifted
  # Cargo.lock be re-resolved against the vendored tree instead of failing; the
  # committed lockfile is the whole point of a pinned build, so require it.
  cargoBuildFlags = [
    "--locked"
    "-p"
    pname
    "-p"
    "${pname}-cli"
  ];

  # Scoped to the two crates we actually ship. The full workspace suite is
  # thousands of tests across forty-odd crates and is upstream's CI job, not a
  # packaging gate; these catch a broken build of what we install.
  cargoTestFlags = [
    "--locked"
    "-p"
    pname
    "-p"
    "${pname}-cli"
  ];
  # Unix-only tests in wordcraft and cadcraft create deliberately non-UTF-8
  # file names. stdenv's /build is on this host's ZFS utf8only dataset, which
  # rejects them; the sandbox's private /dev/shm accepts raw filename bytes.
  # preCheck because stdenv initializes TMPDIR after the derivation environment.
  preCheck = ''
    export TMPDIR=$(mktemp -d -p /dev/shm)
  '';

  # A separate cargo run, after the shipped binaries are built, as cadcraft's
  # package.sh does it: building the example alongside them would unify its
  # clap_mangen/clap_complete dev-dependency features into what we install.
  # The same features as the main build, so cargo reuses those crates rather
  # than recompiling them without the features.
  postBuild = lib.optionalString cliDocs ''
    cargo build -j "$NIX_BUILD_CORES" --offline --locked --profile release \
      --target ${pkgs.stdenv.hostPlatform.rust.rustcTargetSpec} \
      ${
        lib.optionalString (buildFeatures != [ ]) "--features=${lib.concatStringsSep "," buildFeatures}"
      } \
      -p ${pname}-cli --example man-and-completions
    target/${pkgs.stdenv.hostPlatform.rust.rustcTargetSpec}/release/examples/man-and-completions cli-docs
  '';

  postInstall = ''
    install -Dm644 packaging/linux/${appId}.desktop \
      $out/share/applications/${appId}.desktop
    install -Dm644 packaging/linux/${appId}.mime.xml \
      $out/share/mime/packages/${appId}.xml

    # @DATE@ is the build date in upstream's env.sh, which would make the output
    # a function of when it was built. The release date is the reproducible
    # value and the one AppStream actually wants for a <release>.
    mkdir -p $out/share/metainfo
    substitute packaging/linux/${appId}.metainfo.xml.in \
      $out/share/metainfo/${appId}.metainfo.xml \
      --replace-fail '@VERSION@' '${version}' \
      --replace-fail '@DATE@' '${releaseDate}'

    mkdir -p $out/share/icons
    cp -R assets/app-icon/hicolor $out/share/icons/
  ''
  # OFL-1.1 lets the fonts be embedded only if their licences travel with them;
  # craft-fonts' docs/integration.md asks for each family's OFL.txt, named after
  # the family, among the package's licences.
  + lib.optionalString (craftFonts != null) ''
    for licence in ${craftFonts}/fonts/*/OFL.txt; do
      family=$(basename "$(dirname "$licence")")
      install -Dm644 "$licence" "$out/share/licenses/${pname}/fonts/$family-OFL.txt"
    done
  ''
  + lib.optionalString cliDocs ''
    installManPage cli-docs/*.1
    installShellCompletion --cmd ${pname}-cli \
      --bash cli-docs/${pname}-cli.bash \
      --zsh cli-docs/_${pname}-cli \
      --fish cli-docs/${pname}-cli.fish
  '';

  postFixup = ''
    for bin in ${pname} ${pname}-cli; do
      wrapProgram $out/bin/$bin \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibraries}
    done
  '';

  meta = {
    inherit description;
    homepage = "https://getartcraft.com/apps/${pname}";
    changelog = "https://github.com/storytold/${pname}/releases/tag/${rev}";
    license =
      with lib.licenses;
      [
        asl20
        mit
      ]
      ++ lib.optional (craftFonts != null) ofl;
    mainProgram = pname;
    platforms = lib.platforms.linux;
  };
}
