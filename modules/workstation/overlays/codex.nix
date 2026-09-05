_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        codex = prev.stdenv.mkDerivation rec {
          pname = "codex";
          version = "0.146.0";

          src = prev.fetchurl {
            url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
            hash = "sha256-W6O5QFVDlTCB9mHQhU0mb3biq75R1BNJNVo23nZzd2o=";
          };

          sourceRoot = ".";

          nativeBuildInputs = [ prev.makeWrapper ];

          # Static musl binary: nothing to strip or patchelf, and fixup would
          # only mangle it. The wrapper below is written by the makeWrapper
          # setup hook, which is independent of fixupPhase.
          dontFixup = true;

          # Codex sandboxes every command it runs through bwrap and falls back
          # to a bundled copy (with a startup warning) when the real one is
          # absent. bubblewrap is not in systemPackages, so put it on codex's
          # own PATH rather than the whole system's.
          installPhase = ''
            install -Dm755 codex-x86_64-unknown-linux-musl $out/bin/codex

            wrapProgram $out/bin/codex \
              --prefix PATH : ${prev.lib.makeBinPath [ prev.bubblewrap ]}
          '';

          meta = {
            description = "OpenAI Codex CLI - lightweight coding agent for your terminal";
            homepage = "https://github.com/openai/codex";
            platforms = [ "x86_64-linux" ];
            mainProgram = "codex";
          };
        };
      })
    ];
  };
}
