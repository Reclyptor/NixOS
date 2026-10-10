_: {
  flake.modules.homeManager.base =
    {
      pkgs,
      lib,
      ...
    }:
    let
      version = "6.3.0";

      # The published tarball ships a prebuilt dist/ but deliberately omits the
      # lockfile, and buildNpmPackage needs one. The repo's lockfile at the matching
      # tag is dependency-identical to the tarball's package.json (33 deps, both
      # 6.3.0), so npm ci accepts it against the published tree.
      lockfile = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/morluto/rea/rea-agents-${version}/package-lock.json";
        hash = "sha256-kZ+mKVL0SR+LhgKdpzuH4aDe32MfQZXp+7fnDw4gGsw=";
      };

      # Android decompilation wants jadx-headless-mcp, NOT nixpkgs' jadx — a
      # different artifact entirely. rea refuses to fetch it ("REA does not download
      # or install it") and pins an audited revision in dist/android/JadxRelease.js;
      # the hash below is that same audited sha256, re-verified on download.
      jadxRelease = "0.7.1";
      jadxMcpJar = pkgs.fetchurl {
        url = "https://github.com/1013503897/jadx-headless-mcp/releases/download/v${jadxRelease}/jadx-headless-mcp-${jadxRelease}-all.jar";
        hash = "sha256-bl6s9QC2QpK/tzxJeXwZWPbuRGRuQ+hoA5rn/rVz/3U=";
      };

      # REA_PWNTOOLS_PYTHON must be an interpreter that can `import pwnlib`, not the
      # pwntools CLI wrapper that forensics.nix installs.
      pwntoolsPython = pkgs.python3.withPackages (ps: [ ps.pwntools ]);

      rea = pkgs.buildNpmPackage {
        pname = "rea-agents";
        inherit version;

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/rea-agents/-/rea-agents-${version}.tgz";
          hash = "sha256-sWn8Y8BxDUTFxExZwvhx8iR530RHfN+qny5cN8RWOoQ=";
        };
        sourceRoot = "package";

        # prepare/prepack/prepublishOnly are repo-maintenance hooks (turbo artifact
        # generation, Windows-addon verification) with no role in a packaged install.
        # Dependency install scripts are left alone so the node-pty platform package
        # still resolves.
        postPatch = ''
          cp ${lockfile} package-lock.json
          ${lib.getExe pkgs.jq} 'del(.scripts.prepare, .scripts.prepack, .scripts.prepublishOnly)' \
            package.json > package.json.tmp
          mv package.json.tmp package.json
        '';

        npmDepsHash = "sha256-wVk6vZ41FdtneliVtZ1oTo5fSL4lYKrp86xBvYNGo7E=";

        # dist/ arrives compiled, so none of upstream's ~150 npm scripts — tsc,
        # turbo, vitepress, oxlint — need to run here.
        dontNpmBuild = true;
        npmFlags = [ "--omit=dev" ];

        meta = {
          description = "MCP server that reverse-engineers binaries, bundles, APKs, websites and firmware";
          homepage = "https://github.com/morluto/rea";
          license = lib.licenses.mit;
          platforms = lib.platforms.linux;
        };
      };

      reaRoot = "${rea}/lib/node_modules/rea-agents";

      # rea has no PATH-based tool discovery whatsoever — verified by grepping dist/
      # for which/lookPath/commandExists, which finds nothing. Every backend is
      # located purely by environment variable, so exporting store paths here is both
      # the only way to wire it and a guarantee it can never pick up a different
      # ghidra. node is already baked into rea's own bin wrapper; the PATH below is
      # for the subprocesses it spawns (analyzeHeadless is a shell script).
      #
      # Unwired on purpose: Hopper (macOS-only), IDA (commercial), pwndbg (absent
      # from nixpkgs; gef is not a drop-in), unblob (broken on this nixpkgs pin —
      # fs-2.4.16 rejects python3.14 — and binwalk already serves as rea's
      # alternative firmware engine).
      reaMcp = pkgs.writeShellScriptBin "rea-mcp" ''
        set -eu
        export PATH="${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.jdk
          ]
        }:''${PATH:-}"

        export JAVA_HOME="${pkgs.jdk}"
        export GHIDRA_INSTALL_DIR="${pkgs.ghidra}/lib/ghidra"
        export REA_PWNTOOLS_PYTHON="${pwntoolsPython}/bin/python3"
        export REA_BINWALK_COMMAND="${lib.getExe pkgs.binwalk}"
        export REA_MITMDUMP_COMMAND="${pkgs.mitmproxy}/bin/mitmdump"
        export REA_BROWSER_EXECUTABLE="${pkgs.google-chrome}/bin/google-chrome"
        export REA_JADX_MCP_JAR="${jadxMcpJar}"

        # MCP speaks JSON-RPC over stdout; keep anything chattier off it.
        export REA_LOG_LEVEL="''${REA_LOG_LEVEL:-warn}"

        exec ${rea}/bin/rea mcp "$@"
      '';
      mcpBin = "${reaMcp}/bin/rea-mcp";

      # Same per-agent shapes agentmemory.nix uses. rea needs no API key and runs
      # entirely locally, so unlike agentmemory there is no secret to keep out of
      # these files and no token-at-spawn-time wrapper concern.
      mcpServersProg = ''.mcpServers.rea = {command: "${mcpBin}", args: []}'';
      crushProg = ''.["$schema"] = "https://charm.land/crush.json" | .mcp.rea = {type: "stdio", command: "${mcpBin}", args: []}'';
      opencodeProg = ''.["$schema"] = "https://opencode.ai/config.json" | .mcp.rea = {type: "local", command: ["${mcpBin}"], enabled: true}'';

      reaSkill = "reverse-engineer-anything";
      mkSkillLink = dir: {
        name = "${dir}/${reaSkill}";
        value.source = "${reaRoot}/skills/${reaSkill}";
      };
    in
    {
      deepseek.mcpServers.rea.command = mcpBin;

      # Upstream's own skill, linked read-only out of the pinned store path. Same
      # mechanism as the agentmemory skills; the slash command comes from the
      # SKILL.md frontmatter, not the directory name.
      home.file = lib.listToAttrs (
        map mkSkillLink [
          ".claude/skills"
          ".codex/skills"
          ".dsh/skills"
        ]
      );

      # Registers the MCP server with every JSON-configured agent, then appends
      # Codex's TOML block. Ordered after codexConfig because that script
      # regenerates config.toml and would otherwise drop this entry. `rea setup`
      # would do this imperatively; doing it here keeps the pin authoritative and
      # self-heals on every switch.
      home.activation.rea = lib.hm.dag.entryAfter [ "writeBoundary" "codexConfig" ] ''
        rea_merge() {
          local file="$1" prog="$2" base
          $DRY_RUN_CMD mkdir -p "$(dirname "$file")"
          if [ -f "$file" ]; then base="$(cat "$file")"; else base="{}"; fi
          if printf '%s' "$base" | ${lib.getExe pkgs.jq} "$prog" > "$file.rea.tmp"; then
            $DRY_RUN_CMD mv -- "$file.rea.tmp" "$file"
          else
            rm -f "$file.rea.tmp"
            echo "rea: jq merge failed for $file (left unchanged)" >&2
          fi
        }

        rea_merge "$HOME/.claude.json"                   ${lib.escapeShellArg mcpServersProg}
        rea_merge "$HOME/.qwen/settings.json"            ${lib.escapeShellArg mcpServersProg}
        rea_merge "$HOME/.config/crush/crush.json"       ${lib.escapeShellArg crushProg}
        rea_merge "$HOME/.config/opencode/opencode.json" ${lib.escapeShellArg opencodeProg}

        codex_toml="$HOME/.codex/config.toml"
        if [ ! -f "$codex_toml" ]; then
          echo "rea: $codex_toml missing (codexConfig should create it), skipping codex" >&2
        elif ${pkgs.gnugrep}/bin/grep -q '^\[mcp_servers\.rea\]' "$codex_toml"; then
          :
        else
          {
            cat "$codex_toml"
            printf '\n[mcp_servers.rea]\n'
            printf 'command = "%s"\n' "${mcpBin}"
          } > "$codex_toml.rea.tmp"
          $DRY_RUN_CMD mv -- "$codex_toml.rea.tmp" "$codex_toml"
          $DRY_RUN_CMD chmod 600 "$codex_toml"
        fi
      '';
    };
}
