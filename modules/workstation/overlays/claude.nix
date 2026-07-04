{ ... }: {
  flake.modules.nixos.workstation = { config, pkgs, ... }: {
    nixpkgs.overlays = [
      (final: prev: {
        claude-code = prev.stdenvNoCC.mkDerivation rec {
          pname = "claude-code";
          version = "2.1.201";

          src = prev.fetchurl {
            url = "https://registry.npmjs.org/@anthropic-ai/claude-code-linux-x64/-/claude-code-linux-x64-${version}.tgz";
            hash = "sha256-iZmAjpJ5wAtNtN28uBuU9/FzS9fg2UmxMIHeimOnp9w=";
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
            export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
            export CLAUDE_CODE_ENABLE_TASKS=1
            export CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=1
            export ENABLE_TOOL_SEARCH=1
            unset DEV
            export PATH=${prev.lib.makeBinPath [
              prev.procps
              prev.bubblewrap
              prev.socat
            ]}:\$PATH
            # Exec directly (interpreter resolved via nix-ld). Going through
            # ld-linux makes execPath the loader, which breaks Claude Code's
            # bundled grep/find/rg shims (the "-G: ... shared libraries" error).
            exec -a "\$0" "$out/libexec/claude/claude" "\$@"
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
  };
}
