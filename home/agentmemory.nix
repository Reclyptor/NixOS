{ config, pkgs, lib, ... }:
let
  # Host the agentmemory LoadBalancer services are reachable at on the LAN.
  # k3s servicelb exposes each LB port on every node IP, so any node
  # hostname/IP this workstation can reach works. Change if "voideon" does
  # not resolve from here.
  host = "voideon";

  claudeUrl = "http://${host}:3111"; # agentmemory-claude (Claude Code, Codex)
  qwenUrl = "http://${host}:3211"; # agentmemory-qwen (Crush, OpenCode, Qwen Code)

  claudeTokenFile = config.sops.secrets."agentmemory/claude-token".path;
  qwenTokenFile = config.sops.secrets."agentmemory/qwen-token".path;

  # Idempotent wiring of the agentmemory MCP server into each agent's config.
  # The two instances use different bearer tokens, so the token is baked into
  # each agent's MCP env block (a single global env var can't address both).
  # Run once after `nixos-rebuild switch` and after the cluster is reachable.
  agentmemory-wire = pkgs.writeShellApplication {
    name = "agentmemory-wire";
    runtimeInputs = [ pkgs.jq pkgs.coreutils pkgs.gnugrep ];
    text = ''
      claude_url="${claudeUrl}"
      qwen_url="${qwenUrl}"

      claude_tok=""
      qwen_tok=""
      if [ -r "${claudeTokenFile}" ]; then claude_tok="$(cat "${claudeTokenFile}")"; fi
      if [ -r "${qwenTokenFile}" ]; then qwen_tok="$(cat "${qwenTokenFile}")"; fi
      if [ -z "$claude_tok" ]; then
        echo "warning: ${claudeTokenFile} missing/empty — add agentmemory/claude-token to your sops secrets" >&2
      fi
      if [ -z "$qwen_tok" ]; then
        echo "warning: ${qwenTokenFile} missing/empty — add agentmemory/qwen-token to your sops secrets" >&2
      fi

      backup() {
        if [ -f "$1" ]; then cp -- "$1" "$1.agentmemory-bak.$(date +%s)"; fi
      }

      # .mcpServers.agentmemory = { command, args, env }  (Claude Code, Qwen Code)
      wire_mcpservers() {
        local file="$1" url="$2" tok="$3" base
        mkdir -p "$(dirname "$file")"
        backup "$file"
        if [ -f "$file" ]; then base="$(cat "$file")"; else base="{}"; fi
        printf '%s' "$base" | jq --arg url "$url" --arg tok "$tok" \
          '.mcpServers.agentmemory = {command:"npx", args:["-y","@agentmemory/mcp"], env:{AGENTMEMORY_URL:$url, AGENTMEMORY_SECRET:$tok}}' \
          > "$file.tmp"
        mv -- "$file.tmp" "$file"
        echo "  wired $file -> $url"
      }

      # .mcp.agentmemory = { type:"stdio", command, args, env }  (Crush)
      wire_crush() {
        local file="$1" url="$2" tok="$3" base
        mkdir -p "$(dirname "$file")"
        backup "$file"
        if [ -f "$file" ]; then base="$(cat "$file")"; else base="{}"; fi
        printf '%s' "$base" | jq --arg url "$url" --arg tok "$tok" \
          '.["$schema"]="https://charm.land/crush.json" | .mcp.agentmemory = {type:"stdio", command:"npx", args:["-y","@agentmemory/mcp"], env:{AGENTMEMORY_URL:$url, AGENTMEMORY_SECRET:$tok}}' \
          > "$file.tmp"
        mv -- "$file.tmp" "$file"
        echo "  wired $file -> $url"
      }

      # .mcp.agentmemory = { type:"local", command:[...], environment, enabled }  (OpenCode)
      wire_opencode() {
        local file="$1" url="$2" tok="$3" base
        mkdir -p "$(dirname "$file")"
        backup "$file"
        if [ -f "$file" ]; then base="$(cat "$file")"; else base="{}"; fi
        printf '%s' "$base" | jq --arg url "$url" --arg tok "$tok" \
          '.["$schema"]="https://opencode.ai/config.json" | .mcp.agentmemory = {type:"local", command:["npx","-y","@agentmemory/mcp"], environment:{AGENTMEMORY_URL:$url, AGENTMEMORY_SECRET:$tok}, enabled:true}' \
          > "$file.tmp"
        mv -- "$file.tmp" "$file"
        echo "  wired $file -> $url"
      }

      # ~/.codex/config.toml : [mcp_servers.agentmemory] (append if absent)  (Codex)
      wire_codex() {
        local file="$HOME/.codex/config.toml"
        mkdir -p "$(dirname "$file")"
        if [ -f "$file" ] && grep -q '^\[mcp_servers\.agentmemory\]' "$file"; then
          echo "  codex already wired ($file) — remove the [mcp_servers.agentmemory] block to re-wire"
          return
        fi
        backup "$file"
        {
          printf '\n[mcp_servers.agentmemory]\n'
          printf 'command = "npx"\n'
          printf 'args = ["-y", "@agentmemory/mcp"]\n\n'
          printf '[mcp_servers.agentmemory.env]\n'
          printf 'AGENTMEMORY_URL = "%s"\n' "$claude_url"
          printf 'AGENTMEMORY_SECRET = "%s"\n' "$claude_tok"
        } >> "$file"
        echo "  wired $file -> $claude_url"
      }

      echo "Wiring agentmemory MCP into agents:"
      echo "  Claude instance ($claude_url): Claude Code, Codex"
      wire_mcpservers "$HOME/.claude.json" "$claude_url" "$claude_tok"
      wire_codex
      echo "  Qwen instance ($qwen_url): Qwen Code, Crush, OpenCode"
      wire_mcpservers "$HOME/.qwen/settings.json" "$qwen_url" "$qwen_tok"
      wire_crush "$HOME/.config/crush/crush.json" "$qwen_url" "$qwen_tok"
      wire_opencode "$HOME/.config/opencode/opencode.json" "$qwen_url" "$qwen_tok"

      echo
      echo "Done. Restart any running agents to pick up the agentmemory MCP server."
      echo "Optional — Claude Code auto-capture hooks:"
      echo "  npx -y @agentmemory/agentmemory connect claude-code --with-hooks"
    '';
  };
in {
  home.packages = [ agentmemory-wire ];
}
