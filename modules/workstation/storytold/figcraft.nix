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
          version = "0.6.0";
          hash = "sha256-+tZk3xkpazqOn8oCwOLmFCIDtwfIxrpVgfZkq3xDvTM=";
          cargoHash = "sha256-wCI0BFw5JyMGKkPahNP2yRdrCrWpnX241YeYgRYnNyA=";
          releaseDate = "2026-10-14";
          description = "Interface design and prototyping tool";
          craftFontsRev = "43913056ce82a3fdad0ef69f6b88d1dc922a8104";

          # Read by apps/figcraft/build.rs and shown by --version only; nothing
          # reads a build date. FIGCRAFT_DEFAULT_SERVER is left unset, as in the
          # official build: the collaboration server it names is contacted only
          # when sharing online, joining by code or publishing.
          extraEnv = {
            FIGCRAFT_BUILD_SHA = "833f0d2c27f0acbae5394848930ae531fc89c724";
          };
        })
      ];
    };
}
