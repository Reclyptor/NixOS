_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        codex = prev.stdenv.mkDerivation rec {
          pname = "codex";
          version = "0.162.1";

          # The package asset, not the bare `codex-…-musl` one: codex spawns
          # codex-code-mode-host from next to its own binary for every tool
          # call and fails closed without it, and only the package ships it
          # (alongside its rg, bwrap and voice resources). Its layout is read
          # through codex-package.json, so it is installed as one directory.
          src = prev.fetchurl {
            url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-x86_64-unknown-linux-musl.tar.gz";
            hash = "sha256-pnb1ciquDYbL43ZDMvCOqx/didwKMAs61P+/SGEfo+M=";
          };

          sourceRoot = ".";

          nativeBuildInputs = [ prev.makeWrapper ];

          # Static musl binaries plus prebuilt voice libraries: nothing to strip
          # or patchelf, and fixup would only mangle them. The wrapper below is
          # written by the makeWrapper setup hook, which is independent of
          # fixupPhase.
          dontFixup = true;

          # Codex sandboxes every command it runs through bwrap and falls back
          # to a bundled copy (with a startup warning) when the real one is
          # absent. bubblewrap is not in systemPackages, so put it on codex's
          # own PATH rather than the whole system's.
          installPhase = ''
            mkdir -p $out/libexec/codex
            cp -r bin codex-path codex-resources codex-package.json $out/libexec/codex/

            makeWrapper $out/libexec/codex/bin/codex $out/bin/codex \
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
