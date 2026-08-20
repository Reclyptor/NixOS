_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (final: prev: {
        dsh-tui = prev.buildNpmPackage rec {
          pname = "dsh-tui";
          version = "0.8.6";

          # The published tarball, not the git checkout. Both carry the same
          # code — npm's SLSA provenance attestation ties this artifact to the
          # repo's publish workflow — but the tarball ships `lib/` already
          # compiled and its `prepare` script never runs for a registry
          # install, so nothing has to build TypeScript or the vendored
          # submodule here.
          src = prev.fetchurl {
            url = "https://registry.npmjs.org/@deepseek-harness-tui/dsh-tui/-/dsh-tui-${version}.tgz";
            hash = "sha256-oo2fYtrEmrEsMF504eye7VOWg45zsoQGtGfjhBGS0cQ=";
          };

          sourceRoot = "package";

          # Three manifest edits, each load-bearing for `npm ci`:
          #
          #   devDependencies      pull the whole @deepseek-ai harness in as a
          #                        second copy (dsh-web-app depends on ~60 of
          #                        them). Nothing here builds, so they are pure
          #                        weight — and the duplicate copy is worse than
          #                        weight, see the peer note below.
          #
          #   @dsh-std/*           are `workspace:*` specs npm cannot parse. The
          #                        packages themselves ship INSIDE the tarball at
          #                        node_modules/@dsh-std, so they are stashed
          #                        here and restored after npm prunes them as
          #                        extraneous. `vendor/` is the same tree minus
          #                        its manifests — a packing artifact, not a
          #                        usable source root.
          #
          #   bundledDependencies  names those same workspace packages; leaving
          #                        it set makes `npm pack` try to re-bundle
          #                        entries the lockfile no longer knows about.
          #
          # To refresh on a version bump, mirror this exact transform:
          #   tar xzf dsh-tui-<version>.tgz && cd package
          #   jq 'del(.devDependencies) | del(.bundledDependencies)
          #       | .dependencies |= with_entries(
          #           select(.value | startswith("workspace:") | not))' \
          #     package.json > p && mv p package.json
          #   rm -rf node_modules vendor
          #   npm install --package-lock-only --ignore-scripts --omit=dev --legacy-peer-deps
          # then re-run `prefetch-npm-deps package-lock.json` for npmDepsHash.
          postPatch = ''
            ${prev.lib.getExe prev.jq} 'del(.devDependencies)
              | del(.bundledDependencies)
              | .dependencies |= with_entries(
                  select(.value | startswith("workspace:") | not))' \
              package.json > package.json.tmp
            mv package.json.tmp package.json

            mv node_modules/@dsh-std dsh-std-bundled
            rm -rf node_modules vendor

            cp ${./package-lock.json} package-lock.json
          '';

          npmDepsHash = "sha256-CgBfIL476Oda2fstR7tonry/e+UyMWDXt8tnmD/Jg7c=";

          # lib/ is prebuilt in the tarball and nothing needs a native
          # toolchain. --legacy-peer-deps because dsh-working-activity still
          # declares `peerOptional react@^18` while the TUI is on React 19;
          # upstream works around the same manifest bug in its own .npmrc.
          dontNpmBuild = true;
          npmFlags = [
            "--ignore-scripts"
            "--legacy-peer-deps"
          ];

          # The peer deps — 25 @deepseek-ai/* packages — are deliberately absent
          # from the lockfile: they are the harness this plugs into, and a
          # second copy would put two instances of dsh-session and friends in
          # one process, which cordis cannot tolerate because it keys services
          # on module identity.
          #
          # They cannot be left to the profile either. healProfilesModuleFallback
          # does populate $DSH_HOME/profiles/node_modules, and node's upward walk
          # would find them from a profile-relative plugin — but this plugin is
          # a symlink INTO the store, and node resolves from a module's realpath,
          # so that walk climbs /nix/store and never passes the profile at all.
          #
          # So the scope is linked straight to the copy the harness itself loads:
          # profiles/node_modules/@deepseek-ai/* are symlinks to exactly this
          # directory, so both sides resolve to one realpath and node's module
          # cache hands out one instance. It also pins the two together — a dsh
          # bump moves this path and rebuilds the link.
          postInstall =
            let
              packageRoot = "$out/lib/node_modules/@deepseek-harness-tui/dsh-tui";
              harnessScope = "${final.dsh}/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai";
            in
            ''
              ln -s ${harnessScope} ${packageRoot}/node_modules/@deepseek-ai

              # npm prune drops the bundled workspace packages as extraneous
              # (they are not in the lockfile), and npmInstallHook copies
              # node_modules only after that prune — so they go back here.
              mkdir -p ${packageRoot}/node_modules/@dsh-std
              cp -r dsh-std-bundled/. ${packageRoot}/node_modules/@dsh-std/

              # bin/dsh-tui.js is an imperative bootstrapper: on first run it
              # shells out to `dsh plugin add` to write $DSH_HOME/profiles/tui.
              # That directory is declarative here, and its package.json is a
              # read-only store symlink, so the bootstrap could only fail
              # loudly or fight the next activation. Boot the profile with
              # `dsh --profile tui` instead.
              rm -rf $out/bin
            '';

          passthru = {
            packageName = "@deepseek-harness-tui/dsh-tui";
            packageRoot = "${final.dsh-tui}/lib/node_modules/@deepseek-harness-tui/dsh-tui";
          };

          meta = {
            description = "Terminal UI bundle for the DeepSeek Harness";
            homepage = "https://github.com/ccch1mneyyy/dsh-TUI";
            downloadPage = "https://www.npmjs.com/package/@deepseek-harness-tui/dsh-tui";
            license = prev.lib.licenses.mit;
            platforms = prev.lib.platforms.unix;
          };
        };
      })
    ];
  };
}
