{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      codex = prev.stdenv.mkDerivation rec {
        pname = "codex";
        version = "0.111.0";

        src = prev.fetchurl {
          url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-gnu.tar.gz";
          hash = "sha256-E5edP7A//E/ZiA0267lLN6SGiXX/GcUUBXGBPAdsYKA=";
        };

        sourceRoot = ".";

        nativeBuildInputs = [ prev.autoPatchelfHook ];
        buildInputs = [ prev.glibc prev.gcc-unwrapped.lib prev.libcap prev.openssl prev.zlib ];

        installPhase = ''
          install -Dm755 codex-x86_64-unknown-linux-gnu $out/bin/codex
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
}
