_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (final: _prev: {
        # The install steps every store-linked dsh plugin needs, shared so no
        # plugin carries its own copy of them:
        #
        #   ${final.dsh-plugin-install} <name> <entry.js>
        #
        # run from the plugin's installPhase after it has copied itself to $out.
        #
        # Peer. schemastery is a peer dependency, and a store-linked plugin
        # cannot reach it the way a profile-installed one would: node resolves
        # from the realpath of the importing file, which is the plugin's store
        # path, so the walk up never passes ~/.dsh/profiles/node_modules where
        # dsh keeps it. Linking the very copy the harness imports is the point —
        # node caches modules by resolved filename, so the plugin and the
        # harness share one schemastery instance rather than two that fail each
        # other's schema checks.
        #
        # Events. Every event the plugin subscribes to must still be declared
        # by the dsh it runs against. Cordis accepts a listener for an event
        # nobody emits without complaint, which is how dsh 0.2.0's rename of
        # agent/session-start to agent/created took both the mascot and herdr's
        # session restore dark with no error anywhere. The names are read from
        # the plugin's own source, so this check cannot drift from it.
        #
        # Both are coupled to dsh's internal layout on purpose: a layout change
        # becomes a build failure instead of a runtime one.
        dsh-plugin-install = final.writeShellScript "dsh-plugin-install" ''
          set -eu
          name="$1"
          entry="$2"
          dshlib=${final.dsh}/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai

          peer="$dshlib/schemastery"
          if [ ! -d "$peer" ]; then
            echo "$name: schemastery is no longer at $peer;" \
                 "find where the dsh package keeps it and update dsh-plugin-install" >&2
            exit 1
          fi
          mkdir -p "$out/node_modules/@deepseek-ai"
          ln -s "$peer" "$out/node_modules/@deepseek-ai/schemastery"

          events=$(grep -oE "ctx\.on\('[^']+'" "$entry" | cut -d"'" -f2 | sort -u)
          if [ -z "$events" ]; then
            echo "$name: found no ctx.on subscriptions in $entry" >&2
            exit 1
          fi
          for event in $events; do
            if ! grep -rqF --include='*.d.ts' "'$event'(" "$dshlib"; then
              echo "$name: dsh ${final.dsh.version} declares no '$event' event;" \
                   "find what replaced it and update $entry" >&2
              exit 1
            fi
          done
        '';
      })
    ];
  };
}
