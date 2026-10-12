_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        prime-agent = prev.stdenv.mkDerivation rec {
          pname = "prime-agent";
          version = "0.10.0";

          src = prev.fetchurl {
            url = "https://github.com/PrimeIntellect-ai/prime-agent/releases/download/v${version}/prime-agent-${version}-linux-x64.tar.gz";
            hash = "sha256-wWvSr153tT9JuRSkR0LEz2pnxe1QAAQUMLeNvUw7y+w=";
          };

          # The tarball has no top-level directory. Unpack it into one of its
          # own so the payload copied below is exactly the release, without
          # stdenv's build-dir files riding along.
          unpackPhase = ''
            runHook preUnpack
            mkdir payload
            tar -xzf $src -C payload
            cd payload
            runHook postUnpack
          '';

          nativeBuildInputs = [
            prev.autoPatchelfHook
            prev.makeWrapper
          ];

          buildInputs = [ prev.stdenv.cc.cc.lib ];

          # The binary finds its sidecars (prime-agent-runtime/, skills/, the
          # bundled model and MCP catalogs, the photon wasm) next to
          # current_exe(), so the payload stays together as one directory and
          # only the launcher lives in bin/.
          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/prime-agent
            cp -r . $out/share/prime-agent
            rm $out/share/prime-agent/install.sh

            # The store path is read-only, so the self-updater has nothing to
            # update; a new version belongs in this file. The kernel bootstrap
            # takes uv from PATH before it would curl one into ~/.local/bin,
            # and builds its venv from uv's own CPython plus manylinux wheels,
            # which run here through nix-ld (workstation/ld.nix). That venv
            # stays mutable on purpose: Prime Agent installs the skills it
            # writes into it.
            makeWrapper $out/share/prime-agent/prime-agent $out/bin/prime-agent \
              --set PI_SKIP_VERSION_CHECK 1 \
              --set PRIME_AGENT_TELEMETRY 0 \
              --prefix PATH : ${prev.lib.makeBinPath [ prev.uv ]}

            runHook postInstall
          '';

          meta = {
            description = "Prime Intellect's self-improving RLM coding agent";
            homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
            license = prev.lib.licenses.mit;
            platforms = [ "x86_64-linux" ];
            mainProgram = "prime-agent";
          };
        };
      })
    ];
  };
}
