{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      qwen-code = prev.stdenvNoCC.mkDerivation rec {
        pname = "qwen-code";
        version = "0.17.0";

        src = prev.fetchurl {
          url = "https://registry.npmjs.org/@qwen-code/qwen-code/-/qwen-code-${version}.tgz";
          hash = "sha256-b/KPDWYQOKZ88ilNuHuSFHvFD1NuxVCzcq1D9BrkuqQ=";
        };

        sourceRoot = "package";
        dontFixup = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/libexec/qwen-code
          cp -r . $out/libexec/qwen-code/

          install -d $out/bin
          cat > $out/bin/qwen <<EOF
          #!${prev.runtimeShell}
          exec ${prev.lib.getExe prev.nodejs} $out/libexec/qwen-code/cli.js "\$@"
          EOF
          chmod +x $out/bin/qwen

          runHook postInstall
        '';

        meta = {
          description = "Command-line AI workflow tool adapted from Gemini CLI, optimized for Qwen3-Coder models";
          homepage = "https://github.com/QwenLM/qwen-code";
          downloadPage = "https://www.npmjs.com/package/@qwen-code/qwen-code";
          license = prev.lib.licenses.asl20;
          mainProgram = "qwen";
        };
      };
    })
  ];
}
