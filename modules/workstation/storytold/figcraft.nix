# FigCraft — the Figma equivalent: interface design and interactive prototypes
# on an infinite canvas.
#
# The workspace also carries apps/figcraft-server, the relay for live
# collaboration. Upstream ships it on its own, as a service with its own unit
# and proxy configs, not inside the desktop package, so it is not built here.
_: {
  flake.modules.nixos.workstation = import ./_app.nix "figcraft" (
    { pkgs, ... }: {
      version = "0.18.1";
      hash = "sha256-L2mSlcFhvTcJMY2t+WIk+mIJfks6Kr9Sgvz0oHecsK8=";
      cargoHash = "sha256-GVTt+0fo+TfJMlnP5MbdayGN5GLgr0BipZV9LNiB3yI=";
      releaseDate = "2026-11-12";
      description = "Interface design and prototyping tool";
      craftFontsRev = "37827adc41fd165f9a9234ac40f94dbad353aa69";

      # fontique, new in this release's text stack, finds system fonts and
      # fallbacks by dlopening libfontconfig.so.1 (its fontconfig-dlopen
      # feature), so the build needs neither pkg-config nor the headers. Without
      # the library it reports no system fonts rather than failing.
      extraRuntimeLibraries = [ pkgs.fontconfig ];

      # Read by apps/figcraft/build.rs and shown by `figcraft --version` only
      # (figcraft-cli prints its bare version); nothing reads a build date.
      # The other compile-time switches are left unset, as in the official
      # build: FIGCRAFT_DEFAULT_SERVER, whose collaboration server is
      # contacted only when sharing online, joining by code or publishing;
      # FIGCRAFT_DEFAULT_FONT, which keeps new text in Inter; and
      # FIGCRAFT_EMBED_CJK, which leaves CJK text to the system's fonts.
      # FIGCRAFT_EMBED_SCRIPTS and FIGCRAFT_WEB_FONTS, new in 0.18, only shape
      # the wasm build.
      extraEnv = {
        FIGCRAFT_BUILD_SHA = "4acc293c2ec941ac1400837ee7e3ab51780399f8";
      };
    }
  );
}
