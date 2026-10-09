# Shared build for the Storytold craft suite (github.com/storytold): twelve
# clean-room, Apache-2.0/MIT Rust rewrites of the Adobe, Microsoft Office and
# Pro Tools applications, each a cargo workspace of the same shape — `crates/*`
# plus `apps/<name>`, `apps/<name>-cli` and `apps/<name>-web`, with a validated
# freedesktop set under `packaging/linux/`.
#
# ArtCraft is the shared engine the seven Adobe equivalents are built on and the
# name the whole suite shipped under first; the five office and audio apps that
# followed are the same workspace shape and build identically.
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
  # Build scripts that need more than rustc. Kept per-app rather than given to
  # all twelve: four pull alsa-sys (deckcraft, effectcraft, filmcraft,
  # soundcraft) and only pdfcraft builds aws-lc-sys.
  extraNativeBuildInputs ? [ ],
  extraBuildInputs ? [ ],
  # Cargo features. Off by default upstream so distributors can choose; where
  # the official build turns one on, the app module says so.
  buildFeatures ? [ ],
  # Compile-time environment. Four apps read a build provenance through
  # option_env! — photocraft, wordcraft, deckcraft and cadcraft — and are given
  # only the variables they actually read. The other eight carry no option_env!
  # at all, so they pass nothing and this stays an empty attrset, which is what
  # mkDerivation would default to anyway.
  extraEnv ? { },
  # Patches applied to a dependency's vendored sources, as
  # [ { crate = "<name>-<version>"; patch = ./x.patch; } ]. Only pdfcraft needs
  # one, to get past a rustc codegen bug in a transitive dependency — see
  # SPEC/storytold-artcraft-suite.md. Empty for the other eleven, which then take
  # the vendor tree buildRustPackage builds for itself, untouched.
  vendorPatches ? [ ],
}:

let
  appId = "ai.storyteller.${pname}";

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
  # packaging/linux/nfpm.yaml and, in the seven ArtCraft apps, re-checked at
  # start-up in apps/<app>/src/linux_libs.rs.
  #
  # That start-up check is explicitly inconclusive on NixOS (it reads an
  # ldconfig cache we do not have, then warns and continues), and the five office
  # and audio apps ship no equivalent at all, so a library missing here does not
  # produce a friendly "install this package" message — it panics inside
  # xkbcommon-dl before the window opens.
  runtimeLibraries = [
    pkgs.libxkbcommon # libxkbcommon.so.0 and libxkbcommon-x11.so.0
    pkgs.libx11 # libX11.so.6 and libX11-xcb.so.1
    pkgs.libxcb
    pkgs.libxcursor
    pkgs.libxi
    pkgs.wayland # libwayland-client.so.0
    pkgs.vulkan-loader # wgpu's first choice; finds its ICDs under /run/opengl-driver
    pkgs.libGL # libEGL.so.1, wgpu's fallback
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
  # is what the eleven unpatched apps want: passing one explicitly changes the
  # derivation even when the contents are identical, and would rebuild all of
  # them to no purpose.
  cargoDeps = if vendorPatches == [ ] then null else patchedVendor;

  nativeBuildInputs = [ pkgs.makeWrapper ] ++ extraNativeBuildInputs;
  buildInputs = extraBuildInputs;

  env = extraEnv;

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
    license = with lib.licenses; [
      asl20
      mit
    ];
    mainProgram = pname;
    platforms = lib.platforms.linux;
  };
}
