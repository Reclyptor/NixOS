# Shared build for the Storytold ArtCraft suite (github.com/storytold): seven
# clean-room, Apache-2.0/MIT Rust rewrites of the Adobe applications, each a
# cargo workspace of the same shape — `crates/*` plus `apps/<name>`,
# `apps/<name>-cli` and `apps/<name>-web`, with a validated freedesktop set
# under `packaging/linux/`.
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
  # all seven: only effectcraft and filmcraft pull alsa-sys, and only printcraft
  # builds aws-lc-sys.
  extraNativeBuildInputs ? [ ],
  extraBuildInputs ? [ ],
  # Cargo features. Off by default upstream so distributors can choose; where
  # the official build turns one on, the app module says so.
  buildFeatures ? [ ],
}:

let
  appId = "ai.storyteller.${pname}";

  # winit and wgpu dlopen their windowing and GPU libraries, so none of these is
  # an ELF NEEDED entry and nothing in the closure refers to them — the wrapper
  # below is what makes them resolvable at all. The set is upstream's own, from
  # packaging/linux/nfpm.yaml and re-checked at start-up in
  # apps/<app>/src/linux_libs.rs.
  #
  # That start-up check is explicitly inconclusive on NixOS (it reads an
  # ldconfig cache we do not have, then warns and continues), so a library
  # missing here does not produce its friendly "install this package" message —
  # it panics inside xkbcommon-dl before the window opens.
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
    cargoHash
    buildFeatures
    ;

  src = pkgs.fetchFromGitHub {
    owner = "storytold";
    repo = pname;
    inherit rev hash;
  };

  nativeBuildInputs = [ pkgs.makeWrapper ] ++ extraNativeBuildInputs;
  buildInputs = extraBuildInputs;

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
