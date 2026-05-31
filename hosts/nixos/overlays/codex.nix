{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      codex = prev.stdenv.mkDerivation rec {
        pname = "codex";
        version = "0.135.0";

        src = prev.fetchurl {
          url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
          hash = "sha256-oV59rWV9pKDhIO7eKVVv7m1Q6MkZdZzC7Lo8mQmTY+I=";
        };

        sourceRoot = ".";

        dontFixup = true;

        installPhase = ''
          install -Dm755 codex-x86_64-unknown-linux-musl $out/bin/codex
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
