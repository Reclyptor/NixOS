_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        qwen-code = prev.stdenvNoCC.mkDerivation rec {
          pname = "qwen-code";
          version = "0.24.7";

          src = prev.fetchurl {
            url = "https://registry.npmjs.org/@qwen-code/qwen-code/-/qwen-code-${version}.tgz";
            hash = "sha256-ZEMCSKtumW/AxrmgeJNh+GjDuX+D0WIQ4EJOUd/8X6k=";
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
  };
}
