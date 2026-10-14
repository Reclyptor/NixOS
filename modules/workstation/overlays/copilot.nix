_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        # Replaces nixpkgs' github-copilot-cli, which trails npm `latest` by
        # dozens of releases. The platform package is one self-contained ELF
        # that unpacks its JS payload into ~/.cache/copilot/pkg on first run.
        #
        # Refresh: read `latest` from https://registry.npmjs.org/@github/copilot,
        # set `version`, then take the new hash from
        #   nix store prefetch-file --json <src url> | jq -r .hash
        # The platform tarball carries no dependencies, so that is the whole bump.
        github-copilot-cli = prev.stdenvNoCC.mkDerivation rec {
          pname = "github-copilot-cli";
          version = "1.0.97";

          src = prev.fetchurl {
            url = "https://registry.npmjs.org/@github/copilot-linux-x64/-/copilot-linux-x64-${version}.tgz";
            hash = "sha256-O99yqeGSm5u8+JeqNqozthqNt4VgwrcnCBgQltFHSuw=";
          };

          sourceRoot = "package";
          dontFixup = true;

          installPhase = ''
            install -Dm755 copilot $out/libexec/copilot/copilot
            install -d $out/bin

            cat > $out/bin/copilot <<EOF
            #!${prev.runtimeShell}
            # Nix owns the version. This stops both the background download
            # and the launch-time switch to an already-downloaded newer build.
            export COPILOT_AUTO_UPDATE=false
            # Exec directly (interpreter resolved via nix-ld), as claude-code does.
            exec -a "\$0" "$out/libexec/copilot/copilot" "\$@"
            EOF

            chmod +x $out/bin/copilot
          '';

          meta = {
            description = "GitHub Copilot's agentic coding assistant for the terminal";
            homepage = "https://github.com/github/copilot-cli";
            downloadPage = "https://www.npmjs.com/package/@github/copilot";
            license = prev.lib.licenses.unfree;
            mainProgram = "copilot";
            platforms = [ "x86_64-linux" ];
          };
        };
      })
    ];
  };
}
