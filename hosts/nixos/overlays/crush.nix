{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      crush = prev.stdenv.mkDerivation rec {
        pname = "crush";
        version = "0.74.1";

        src = prev.fetchurl {
          url = "https://github.com/charmbracelet/crush/releases/download/v${version}/crush_${version}_Linux_x86_64.tar.gz";
          hash = "sha256-imxX2CQhbEjqKseYvcaYKA7Yf/k0vhPda9Xghb9DJPE=";
        };

        sourceRoot = "crush_${version}_Linux_x86_64";

        nativeBuildInputs = [
          prev.autoPatchelfHook
          prev.installShellFiles
        ];

        buildInputs = [
          prev.stdenv.cc.cc.lib
        ];

        installPhase = ''
          runHook preInstall

          install -Dm755 crush $out/bin/crush

          installManPage manpages/crush.1.gz

          installShellCompletion \
            --bash completions/crush.bash \
            --fish completions/crush.fish \
            --zsh  completions/crush.zsh

          install -Dm644 LICENSE.md $out/share/doc/crush/LICENSE.md
          install -Dm644 README.md  $out/share/doc/crush/README.md

          runHook postInstall
        '';

        meta = {
          description = "Glamorous AI coding agent for your favourite terminal";
          homepage = "https://github.com/charmbracelet/crush";
          license = prev.lib.licenses.fsl11Mit;
          platforms = [ "x86_64-linux" ];
          mainProgram = "crush";
        };
      };
    })
  ];
}
