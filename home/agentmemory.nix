{ config, pkgs, lib, ... }:
let
  # agentmemory LoadBalancer endpoints on the LAN (shared Cilium IP, distinct ports).
  claudeURL = "http://192.168.1.120:3111"; # agentmemory-claude (Claude Code, Codex)
  qwenURL = "http://192.168.1.120:3211"; # agentmemory-qwen (Qwen Code, Crush, OpenCode)

  claudeTokenFile = config.sops.secrets."agentmemory/claude-token".path;
  qwenTokenFile = config.sops.secrets."agentmemory/qwen-token".path;

  # Per-agent jq programs that set only the agentmemory MCP entry and leave the rest
  # of each config untouched. $url/$tok are supplied via `jq --arg`. The two instances
  # use different bearer tokens, so the token is baked into each agent's env block.
  mcpServersProg = ''.mcpServers.agentmemory = {command: "npx", args: ["-y", "@agentmemory/mcp"], env: {AGENTMEMORY_URL: $url, AGENTMEMORY_SECRET: $tok}}'';
  crushProg = ''.["$schema"] = "https://charm.land/crush.json" | .mcp.agentmemory = {type: "stdio", command: "npx", args: ["-y", "@agentmemory/mcp"], env: {AGENTMEMORY_URL: $url, AGENTMEMORY_SECRET: $tok}}'';
  opencodeProg = ''.["$schema"] = "https://opencode.ai/config.json" | .mcp.agentmemory = {type: "local", command: ["npx", "-y", "@agentmemory/mcp"], environment: {AGENTMEMORY_URL: $url, AGENTMEMORY_SECRET: $tok}, enabled: true}'';
in {
  # Single source of truth for all agentmemory MCP wiring. The four JSON agents are
  # jq-merged in place; Codex uses TOML and is appended onto the base config that
  # home/codex.nix regenerates — hence the "codexConfig" ordering dependency. Runs
  # after sops-nix so the bearer tokens are decrypted and on disk. Self-heals on
  # every `nixos-rebuild switch`.
  home.activation.agentmemory = lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" "codexConfig" ] ''
    am_merge() {
      local file="$1" prog="$2" url="$3" tok="$4" base
      if [ -z "$tok" ]; then
        echo "agentmemory: token empty, skipping $file" >&2
        return
      fi
      $DRY_RUN_CMD mkdir -p "$(dirname "$file")"
      if [ -f "$file" ]; then base="$(cat "$file")"; else base="{}"; fi
      if printf '%s' "$base" | ${pkgs.jq}/bin/jq --arg url "$url" --arg tok "$tok" "$prog" > "$file.am.tmp"; then
        $DRY_RUN_CMD mv -- "$file.am.tmp" "$file"
      else
        rm -f "$file.am.tmp"
        echo "agentmemory: jq merge failed for $file (left unchanged)" >&2
      fi
    }

    claude_tok=""
    if [ -r "${claudeTokenFile}" ]; then claude_tok="$(cat "${claudeTokenFile}")"; fi
    qwen_tok=""
    if [ -r "${qwenTokenFile}" ]; then qwen_tok="$(cat "${qwenTokenFile}")"; fi
    if [ -z "$claude_tok" ]; then echo "agentmemory: ${claudeTokenFile} missing/empty — claude-instance agents not wired" >&2; fi
    if [ -z "$qwen_tok" ]; then echo "agentmemory: ${qwenTokenFile} missing/empty — qwen-instance agents not wired" >&2; fi

    # JSON agents (jq merge, non-destructive).
    am_merge "$HOME/.claude.json"                   ${lib.escapeShellArg mcpServersProg} "${claudeURL}" "$claude_tok"
    am_merge "$HOME/.qwen/settings.json"            ${lib.escapeShellArg mcpServersProg} "${qwenURL}"   "$qwen_tok"
    am_merge "$HOME/.config/crush/crush.json"       ${lib.escapeShellArg crushProg}      "${qwenURL}"   "$qwen_tok"
    am_merge "$HOME/.config/opencode/opencode.json" ${lib.escapeShellArg opencodeProg}   "${qwenURL}"   "$qwen_tok"

    # Codex (TOML): append the agentmemory block onto the base config that
    # home/codex.nix just regenerated. codexConfig strips any prior block (its awk
    # preserves only [projects.*]), so this re-adds it deterministically each run.
    codex_toml="$HOME/.codex/config.toml"
    if [ -z "$claude_tok" ]; then
      echo "agentmemory: token empty, skipping codex" >&2
    elif [ ! -f "$codex_toml" ]; then
      echo "agentmemory: $codex_toml missing (codexConfig should create it), skipping codex" >&2
    elif ${pkgs.gnugrep}/bin/grep -q '^\[mcp_servers\.agentmemory\]' "$codex_toml"; then
      : # an actual [mcp_servers.agentmemory] table header is already present
    else
      {
        cat "$codex_toml"
        printf '\n[mcp_servers.agentmemory]\n'
        printf 'command = "npx"\n'
        printf 'args = ["-y", "@agentmemory/mcp"]\n\n'
        printf '[mcp_servers.agentmemory.env]\n'
        printf 'AGENTMEMORY_URL = "%s"\n' "${claudeURL}"
        printf 'AGENTMEMORY_SECRET = "%s"\n' "$claude_tok"
      } > "$codex_toml.am.tmp"
      $DRY_RUN_CMD mv -- "$codex_toml.am.tmp" "$codex_toml"
      $DRY_RUN_CMD chmod 600 "$codex_toml"
    fi
  '';
}
