_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        dsh = prev.buildNpmPackage rec {
          pname = "dsh";
          version = "0.1.0-rc.7";

          src = prev.fetchurl {
            url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${version}.tgz";
            hash = "sha256-L48Ldj1hGsU296lBHuQ8CvwGfBuHMsMQLATb45i8rMU=";
          };

          sourceRoot = "package";

          # Unlike claude-code (a prebuilt native binary) and qwen-code (one
          # bundled cli.js), dsh is a thin launcher over ~60 @deepseek-ai/dsh-*
          # plugin packages, so the dependency tree has to be resolved here. The
          # published tarball ships no lockfile and npm ci demands one, so we
          # vendor it. To refresh on a version bump:
          #   tar xzf dsh-<version>.tgz && cd package
          #   npm install --package-lock-only --ignore-scripts
          # then re-run `prefetch-npm-deps package-lock.json` for npmDepsHash.
          postPatch = ''
            cp ${./package-lock.json} package-lock.json
          '';

          npmDepsHash = "sha256-Y+Y1f1V7+1sXkezKAeqEOW8GZeScERo/+gWXU4Qjqho=";

          # lib/ is already built in the published tarball, and nothing in the
          # tree needs a native toolchain, so both hooks are dead weight.
          dontNpmBuild = true;
          npmFlags = [ "--ignore-scripts" ];

          # Replaces the generated bin rather than wrapping it, because the fix
          # below is a node flag and has to reach the interpreter itself.
          #
          # --expose-internals: cordis-plugin-hmr throws "--expose-internals is
          # required for HMR service" on Node 24 and takes the whole boot down
          # with it, on both the web and headless profiles. This is upstream,
          # not a packaging artifact — a plain `npm i @deepseek-ai/dsh` fails
          # identically. The flag cannot go in NODE_OPTIONS ("not allowed"), so
          # it has to be on the argv. Revisit once the dev preview settles; the
          # composition already intends HMR off outside plugin development.
          #
          # PATH: `dsh plugin add` shells out to pnpm inside $DSH_HOME/profiles,
          # and the agent's own tooling reaches for git and ripgrep. None are
          # resolvable from the store path on their own.
          postInstall = ''
            rm -f $out/bin/dsh

            cat > $out/bin/dsh <<EOF
            #!${prev.runtimeShell}
            export PATH=${
              prev.lib.makeBinPath [
                prev.pnpm
                prev.nodejs
                prev.git
                prev.ripgrep
              ]
            }:\$PATH
            exec ${prev.lib.getExe prev.nodejs} --expose-internals \
              $out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js "\$@"
            EOF

            chmod +x $out/bin/dsh
          '';

          meta = {
            description = "DeepSeek Harness: plugin-composed agent runtime where every capability is a plugin";
            homepage = "https://github.com/deepseek-ai/deepseek-harness";
            downloadPage = "https://www.npmjs.com/package/@deepseek-ai/dsh";
            license = prev.lib.licenses.mit;
            mainProgram = "dsh";
          };
        };
      })
    ];
  };
}
