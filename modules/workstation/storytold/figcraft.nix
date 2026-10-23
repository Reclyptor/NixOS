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
          version = "0.10.0";
          hash = "sha256-GTcEYs6BUqcA3AhXph1uZM78Z1N2FgljW1X5oaoim7I=";
          cargoHash = "sha256-/ovHS9Psoaonak7k3BGo2PPeH441Tec9WE047pzHoGA=";
          releaseDate = "2026-10-22";
          description = "Interface design and prototyping tool";
          craftFontsRev = "43913056ce82a3fdad0ef69f6b88d1dc922a8104";

          # Read by apps/figcraft/build.rs and shown by --version only; nothing
          # reads a build date. FIGCRAFT_DEFAULT_SERVER is left unset, as in the
          # official build: the collaboration server it names is contacted only
          # when sharing online, joining by code or publishing.
          extraEnv = {
            FIGCRAFT_BUILD_SHA = "80f916326fb94f3a88cb24e64f396f564a0ebc06";
          };
        })
      ];
    };
}
