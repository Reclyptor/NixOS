{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      claude-code = prev.stdenvNoCC.mkDerivation rec {
        pname = "claude-code";
        version = "2.1.141";

        src = prev.fetchurl {
          url = "https://registry.npmjs.org/@anthropic-ai/claude-code-linux-x64/-/claude-code-linux-x64-${version}.tgz";
          hash = "sha256-CM8e767zKRQ0KLhl5i/6QjqYs0n8U0yX47xXiPibDsM=";
        };

        sourceRoot = "package";
        dontFixup = true;

        installPhase = ''
          install -Dm755 claude $out/libexec/claude/claude
          install -d $out/bin

          cat > $out/bin/claude <<EOF
          #!${prev.runtimeShell}
          export DISABLE_AUTOUPDATER=1
          export DISABLE_INSTALLATION_CHECKS=1
          unset DEV
          export PATH=${prev.lib.makeBinPath [
            prev.procps
            prev.bubblewrap
            prev.socat
          ]}:\$PATH
          exec -a "\$0" ${prev.glibc}/lib64/ld-linux-x86-64.so.2 \\
            --library-path ${prev.glibc}/lib \\
            "$out/libexec/claude/claude" "\$@"
          EOF

          chmod +x $out/bin/claude
        '';

        meta = {
          description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
          homepage = "https://github.com/anthropics/claude-code";
          downloadPage = "https://www.npmjs.com/package/@anthropic-ai/claude-code";
          license = prev.lib.licenses.unfree;
          mainProgram = "claude";
        };
      };
    })
  ];
}
