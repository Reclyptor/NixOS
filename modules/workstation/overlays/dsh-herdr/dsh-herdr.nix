_: {
  flake.modules.nixos.workstation =
    { lib, ... }:
    {
      nixpkgs.overlays = [
        (_final: prev: {
          # The upstream-sanctioned way to give herdr a dsh agent's state: a dsh
          # bundle that reports lifecycle from the harness's own events —
          # tools/execute for the working label, the approval and user-question
          # waterfalls for blocked — plus the session ref and pane metadata,
          # over herdr's documented pane socket API.
          #
          # herdr's maintainers pointed at exactly this path when they closed
          # herdrdev/herdr#2967 ("adding [dsh] would be new agent support";
          # "dsh-tui can report lifecycle state today through the documented
          # custom integration API"), so this is their answer rather than our
          # workaround. Event-driven state also beats the screen manifest in our
          # own patch, which stays as the fallback when this bundle is absent.
          #
          # Reviewed before adoption: its only IO is node:net to
          # $HERDR_SOCKET_PATH, it is a strict no-op unless HERDR_ENV=1 with a
          # pane id, and its transport fails open (500ms timeout, one retry,
          # never rejects into dsh). No child_process, no HTTP, no disk writes.
          #
          # schemastery is a peer dependency that ships inside the dsh
          # installation, so this package carries no node_modules of its own —
          # an unpacked tarball is the whole build.
          dsh-herdr =
            let
              version = "0.3.0";
              self = prev.stdenvNoCC.mkDerivation {
                pname = "dsh-herdr-agent-state";
                inherit version;

                src = prev.fetchurl {
                  url = "https://registry.npmjs.org/@dsh-blue/herdr-agent-state/-/herdr-agent-state-${version}.tgz";
                  hash = "sha256-R2GK/tGiehFqj0qbO34G4VbI/1vz7g9kHDNNWXD+nBE=";
                };

                sourceRoot = "package";
                dontBuild = true;
                dontFixup = true;

                installPhase = ''
                  runHook preInstall
                  mkdir -p $out
                  cp -r . $out/
                  runHook postInstall
                '';

                passthru = {
                  packageName = "@dsh-blue/herdr-agent-state";
                  packageRoot = self;
                };

                meta = {
                  description = "dsh bundle reporting agent state, session ref and pane metadata to herdr";
                  homepage = "https://github.com/dsh-blue/herdr-agent-state";
                  license = lib.licenses.mit;
                  platforms = lib.platforms.all;
                };
              };
            in
            self;
        })
      ];
    };
}
