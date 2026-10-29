# FigCraft — the Figma equivalent: interface design and interactive prototypes
# on an infinite canvas.
#
# The workspace also carries apps/figcraft-server, the relay for live
# collaboration. Upstream ships it on its own, as a service with its own unit
# and proxy configs, not inside the desktop package, so it is not built here.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "figcraft";
          version = "0.12.1";
          hash = "sha256-rdnFZGi7YeGtcfpRgY8ICp0sXOKNqX1vCwBAvZxXKxo=";
          cargoHash = "sha256-aFD3NwF6+y6sG1OlZIhE0G6I7iNNxwgWihC760/eKCs=";
          releaseDate = "2026-10-28";
          description = "Interface design and prototyping tool";
          craftFontsRev = "37827adc41fd165f9a9234ac40f94dbad353aa69";

          # Read by apps/figcraft/build.rs and shown by `figcraft --version` only
          # (figcraft-cli prints its bare version); nothing reads a build date.
          # The other compile-time switches are left unset, as in the official
          # build: FIGCRAFT_DEFAULT_SERVER, whose collaboration server is
          # contacted only when sharing online, joining by code or publishing;
          # FIGCRAFT_DEFAULT_FONT, which keeps new text in Inter; and
          # FIGCRAFT_EMBED_CJK, which leaves CJK text to the system's fonts.
          extraEnv = {
            FIGCRAFT_BUILD_SHA = "ef9721c5b9d0f1cc19a74449cbe175fc06bf8efa";
          };
        })
      ];
    };
}
