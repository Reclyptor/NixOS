_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        codeburn = prev.buildNpmPackage rec {
          pname = "codeburn";
          version = "0.9.23";

          # The published tarball, not the git checkout. `npm run build` does
          # three things a sandbox cannot: scripts/bundle-litellm.mjs downloads
          # the pricing table off raw.githubusercontent.com, build:dash runs a
          # nested `npm install` inside dash/, and tsup wants the whole dev
          # toolchain. The tarball ships all three outputs already built —
          # dist/main.js, dist/parse-worker.js, dist/dash — so nothing here
          # builds and nothing reaches the network.
          src = prev.fetchurl {
            url = "https://registry.npmjs.org/codeburn/-/codeburn-${version}.tgz";
            hash = "sha256-HX870+Ra9rvhZ+JUaLXPv1o9E3E5Mnp3Vk85cH4hSlA=";
          };

          sourceRoot = "package";

          # What the tarball does NOT ship is node_modules, and dist/main.js
          # still imports ten packages by bare specifier (ink, react, commander,
          # zod, undici, chalk, strip-ansi, selfsigned, bonjour-service,
          # @modelcontextprotocol/sdk). So `npm ci` has to run, and it needs a
          # lockfile upstream does not publish.
          #
          # devDependencies go first: playwright, vitest, typescript and tsup
          # are pure weight when nothing builds — dropping them takes the
          # lockfile from several hundred packages to 162.
          #
          # To refresh on a version bump, mirror this exact transform:
          #   tar xzf codeburn-<version>.tgz && cd package
          #   jq 'del(.devDependencies)' package.json > p && mv p package.json
          #   rm -rf node_modules
          #   npm install --package-lock-only --ignore-scripts --omit=dev
          # then re-run `prefetch-npm-deps package-lock.json` for npmDepsHash.
          postPatch = ''
            ${prev.lib.getExe prev.jq} 'del(.devDependencies)' \
              package.json > package.json.tmp
            mv package.json.tmp package.json

            cp ${./package-lock.json} package-lock.json
          '';

          npmDepsHash = "sha256-XKwT9q09+2hK6ktNKkA74GjhdO3ww/LJg8sA/G6uTbo=";

          dontNpmBuild = true;
          npmFlags = [ "--ignore-scripts" ];

          meta = {
            description = "Local-first token and cost tracker for AI coding agents";
            homepage = "https://github.com/getagentseal/codeburn";
            downloadPage = "https://www.npmjs.com/package/codeburn";
            license = prev.lib.licenses.mit;
            platforms = prev.lib.platforms.unix;
            mainProgram = "codeburn";
          };
        };
      })
    ];
  };
}
