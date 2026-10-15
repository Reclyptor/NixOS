_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        prime-agent =
          let
            # Upstream #3509 (tracked in discussion #3510 / #3489): a print run
            # with no model flags ignores settings.json's defaultProvider and
            # defaultModel, and even PRIME_AGENT_MODEL, and takes the first
            # logged-in catalog provider's built-in model instead — so
            # `prime-agent -p` from a script never reaches the configured
            # default. Sourced by the wrapper so it can prepend that default
            # as the flags upstream does honor. It steps aside whenever the
            # caller names a model, or resumes, continues or forks a session
            # (which carries its own model), and when either setting is unset,
            # leaving upstream's behaviour. Prime saves a flagged run's model
            # as the default, which here is the same value. Drop once a
            # release reads the default in print mode.
            printDefault = prev.writeText "prime-agent-print-default.sh" ''
              print_default=0
              for arg in "$@"; do
                case "$arg" in
                  -p | --print) print_default=1 ;;
                esac
              done
              for arg in "$@"; do
                case "$arg" in
                  --provider | --provider=* | --model | --model=* | --models | --models=* | \
                    -c | --continue | -r | --resume | --resume=* | --fork | --fork=*)
                    print_default=0 ;;
                esac
              done
              if [ "$print_default" = 1 ]; then
                settings="''${PRIME_AGENT_CODING_AGENT_DIR:-$HOME/.prime/agent}/settings.json"
                if defaults="$(${prev.lib.getExe prev.jq} -r \
                  'select((.defaultProvider | type) == "string" and (.defaultModel | type) == "string")
                   | .defaultProvider, .defaultModel' "$settings" 2>/dev/null)" && [ -n "$defaults" ]; then
                  { read -r default_provider; read -r default_model; } <<< "$defaults"
                  set -- --provider "$default_provider" --model "$default_model" "$@"
                fi
                unset default_provider default_model defaults settings
              fi
              unset print_default arg
            '';
          in
          prev.stdenv.mkDerivation rec {
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
                --prefix PATH : ${prev.lib.makeBinPath [ prev.uv ]} \
                --run "source ${printDefault}"

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
