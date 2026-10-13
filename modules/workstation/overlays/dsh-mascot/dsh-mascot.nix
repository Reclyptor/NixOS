_: {
  flake.modules.nixos.workstation =
    { lib, ... }:
    {
      nixpkgs.overlays = [
        (final: prev: {
          # A dsh bundle that reports session state to the ESP32 desk mascot.
          #
          # Claude Code and Codex reach the device through their hook seams
          # (home/claude/mascot.nix). dsh does have a Claude Code hook bridge
          # since 0.2.0, but it does not dispatch PermissionRequest or
          # SessionEnd, so through it dsh could never say "waiting on you" and
          # its rows could only ever time out. The approval and user-question
          # waterfalls carry exactly that, so this is a native Cordis plugin on
          # dsh's own extension points instead.
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
                version = "0.2.0";

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
                  # layout change into a build failure instead of a runtime one.
                  peer=${final.dsh}/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/schemastery
                  if [ ! -d "$peer" ]; then
                    echo "dsh-mascot: schemastery is no longer at $peer;" \
                         "find where the dsh package keeps it and update this path" >&2
                    exit 1
                  fi
                  mkdir -p $out/node_modules/@deepseek-ai
                  ln -s "$peer" $out/node_modules/@deepseek-ai/schemastery

                  # Every event the plugin subscribes to must still be declared
                  # by the dsh it runs against. Cordis accepts a listener for
                  # an event nobody emits without complaint, which is how the
                  # 0.2.0 rename of agent/session-start to agent/created took
                  # the mascot dark with no error anywhere. The names are read
                  # from the source itself so this list cannot drift from it.
                  dshlib=${final.dsh}/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai
                  events=$(grep -oE "ctx\.on\('[^']+'" src/index.js | cut -d"'" -f2 | sort -u)
                  if [ -z "$events" ]; then
                    echo "dsh-mascot: found no ctx.on subscriptions in src/index.js" >&2
                    exit 1
                  fi
                  for event in $events; do
                    if ! grep -rqF --include='*.d.ts' "'$event'(" "$dshlib"; then
                      echo "dsh-mascot: dsh ${final.dsh.version} declares no '$event' event;" \
                           "find what replaced it and update src/index.js" >&2
                      exit 1
                    fi
                  done

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
