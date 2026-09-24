_: {
  flake.modules.nixos.workstation =
    { lib, ... }:
    {
      nixpkgs.overlays = [
        (final: prev: {
          # A dsh bundle that reports session state to the ESP32 desk mascot.
          #
          # dsh has no lifecycle-hook seam — unlike Claude Code and Codex, which
          # the mascot reaches through home/claude/mascot.nix — so the only
          # supported way in is a Cordis plugin using dsh's documented extension
          # points. That is the same path dsh-herdr takes, and it is dsh's
          # sanctioned answer rather than a workaround.
          #
          # The waterfalls are why this is worth building: approval/request and
          # user-questions/request give a real "waiting on you" signal. Codex
          # cannot produce one at all, so of the three harnesses dsh is second
          # only to Claude in what it can tell the device.
          #
          # Every waterfall subscription is an observer: it delegates with
          # `await next()` and never alters the downstream decision, so
          # approvals, questions and tool dispatch behave exactly as they would
          # without it. The transport swallows every failure and is never
          # awaited, so the mascot being absent, asleep or mid-reflash cannot
          # disturb the harness.
          #
          # Source lives in ./bundle rather than being fetched: it is ours, and
          # vendoring it keeps the plugin and this comment in one commit.
          dsh-mascot =
            let
              self = prev.stdenvNoCC.mkDerivation {
                pname = "dsh-mascot-agent-state";
                version = "0.1.0";

                src = ./bundle;

                dontBuild = true;
                dontFixup = true;

                installPhase = ''
                  runHook preInstall
                  mkdir -p $out
                  cp -r . $out/

                  # schemastery is a peer dependency, and a store-linked plugin
                  # cannot reach it the way a profile-installed one would: node
                  # resolves from the realpath of the importing file, which is
                  # this store path, so the walk up never passes
                  # ~/.dsh/profiles/node_modules where dsh keeps it.
                  #
                  # Linking the very copy the harness imports is the point —
                  # node caches modules by resolved filename, so the plugin and
                  # the harness share one schemastery instance rather than two
                  # that fail each other's schema checks. The guard turns a dsh
                  # layout change into a build failure instead of a runtime one,
                  # exactly as the dsh-herdr overlay does.
                  peer=${final.dsh}/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/schemastery
                  if [ ! -d "$peer" ]; then
                    echo "dsh-mascot: schemastery is no longer at $peer;" \
                         "find where the dsh package keeps it and update this path" >&2
                    exit 1
                  fi
                  mkdir -p $out/node_modules/@deepseek-ai
                  ln -s "$peer" $out/node_modules/@deepseek-ai/schemastery

                  runHook postInstall
                '';

                passthru = {
                  packageName = "@reclyptor/mascot-agent-state";
                  packageRoot = self;
                };

                meta = {
                  description = "dsh bundle reporting session state to the ESP32 desk mascot";
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
