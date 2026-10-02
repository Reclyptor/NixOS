_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (
        _final: prev:
        let
          # The interpreter dsh itself runs under. dsh 0.2.0 boots through
          # node-addon-require-builtin, which locates Node's
          # PrincipalRealm::builtin_module_require getter and decodes its
          # machine code to recover the field offset holding requireBuiltin.
          # Its x64 SysV decoder recognises exactly `mov off(%rdi),%rax` into a
          # return and nothing else. nixpkgs carries zerocallusedregs in
          # defaultHardeningFlags, which emits `xor %edi,%edi` between the load
          # and the `ret`, so the decode fails and every boot dies with
          #   node-addon-require-builtin unsupported: Unsupported/no-getter
          #   (x64 sysv getter is not a recognized this->field accessor)
          # Dropping that one flag restores the two-instruction getter the addon
          # can read. nodejs-slim is where the binary is actually built —
          # nixpkgs' `nodejs` only symlinks node out of it — so the override has
          # to happen here to reach the code generation.
          #
          # Scoped to dsh on purpose: nothing else on the system gives up the
          # hardening, and the build below still uses the stock nodejs. 0.1.x
          # never hit this because it took requireBuiltin from
          # --expose-internals instead of reading it out of the Realm.
          nodejsForDsh = prev.nodejs-slim.overrideAttrs (old: {
            hardeningDisable = (old.hardeningDisable or [ ]) ++ [ "zerocallusedregs" ];

            # Building Node from source means its test suite actually runs here,
            # and two tests assert on filenames holding invalid UTF-8. This
            # machine's store is a ZFS dataset with utf8only=on, which refuses
            # such names at the syscall (EILSEQ), so both fail for a filesystem
            # reason that has nothing to do with Node or this override — the
            # cached upstream build simply never ran them on this host. The
            # remaining ~5000 tests are kept.
            postPatch = (old.postPatch or "") + ''
              rm -f test/parallel/test-fileurltopathbuffer.js \
                    test/parallel/test-fs-readdir-ucs2.js
            '';
          });
        in
        {
          dsh = prev.buildNpmPackage rec {
            pname = "dsh";
            version = "0.2.0-rc.2";

            src = prev.fetchurl {
              url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${version}.tgz";
              hash = "sha256-vSeEfERc1opWWsH5HAa7vMdjnvkwcfZ4u1nF66/ziFk=";
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

            npmDepsHash = "sha256-sx/nXrhS9U3NhEOEmcEpzDm06lSh9MQBDb6vqD0AG6o=";

            # lib/ is already built in the published tarball, and nothing in the
            # tree needs a native toolchain, so both hooks are dead weight.
            dontNpmBuild = true;
            npmFlags = [ "--ignore-scripts" ];

            # Replaces the generated bin rather than wrapping it, because the fix
            # below is a node flag and has to reach the interpreter itself.
            #
            # --expose-internals: the HMR service — @deepseek-ai/dsh-hmr, which
            # was cordis-plugin-hmr before 0.2.0 — still throws "--expose-internals
            # is required for HMR service" straight from its constructor on Node 24
            # and takes the whole boot down with it, on both the web and headless
            # profiles. This is upstream,
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
              # This wrapper execs node, so the foreground process herdr sees is
              # "node" and its agent detection cannot name it. HERDR_AGENT is the
              # documented remedy for exactly that shape — herdr reads it out of
              # /proc/<pid>/environ (parse_agent_env_hint) and uses the deepseek
              # manifest. Inert when herdr is not running.
              export HERDR_AGENT=deepseek
              export PATH=${
                prev.lib.makeBinPath [
                  prev.pnpm
                  nodejsForDsh
                  prev.git
                  prev.ripgrep
                ]
              }:\$PATH
              exec ${nodejsForDsh}/bin/node --expose-internals \
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
        }
      )
    ];
  };
}
