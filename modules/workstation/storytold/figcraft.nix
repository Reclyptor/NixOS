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
          version = "0.7.0";
          hash = "sha256-0K9K3EEe/HKpufzW8ym9NUwsNpioUvPUxV9rxpoJU2Q=";
          cargoHash = "sha256-BdDJmIoTAH06y+bvfY8WyzxgV7572oxSdkA8kN4wz4E=";
          releaseDate = "2026-10-18";
          description = "Interface design and prototyping tool";
          craftFontsRev = "43913056ce82a3fdad0ef69f6b88d1dc922a8104";

          # Read by apps/figcraft/build.rs and shown by --version only; nothing
          # reads a build date. FIGCRAFT_DEFAULT_SERVER is left unset, as in the
          # official build: the collaboration server it names is contacted only
          # when sharing online, joining by code or publishing.
          extraEnv = {
            FIGCRAFT_BUILD_SHA = "47438dd4a2e8b49a7e6bb3dfd480262dadc37f12";
          };
        })
      ];
    };
}
