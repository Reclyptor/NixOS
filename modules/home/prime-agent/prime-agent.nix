_: {
  flake.modules.homeManager.base =
    { lib, pkgs, ... }:
    let
      # Prime Agent owns ~/.prime/agent/settings.json — /model, /login and the
      # settings menu all write it — so Nix only fills in a default provider
      # when none is chosen yet and never overrides a choice made in-app. Both
      # keys travel together: a model id is only meaningful for its provider.
      # The pin matters because Prime Agent's own anthropic default lags the
      # current Opus.
      defaultsProg = ''
        if .defaultProvider == null
        then .defaultProvider = "anthropic" | .defaultModel = "claude-opus-5-5"
        else .
        end
      '';
    in
    {
      # Global Prime Agent directives, installed read-only as
      # ~/.prime/agent/AGENTS.md. Prime Agent loads the agent-dir AGENTS.md as
      # its global context file, layered over its own system prompt rather than
      # replacing it — that is SYSTEM.md, which stays absent on purpose. /refine
      # writes only to its harness-state dir, so nothing contests the link.
      # Edit ./AGENTS.md next to this module.
      home.file.".prime/agent/AGENTS.md".source = ./AGENTS.md;

      home.activation.primeAgentSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings="$HOME/.prime/agent/settings.json"
        $DRY_RUN_CMD mkdir -p "$(dirname "$settings")"
        if [ -f "$settings" ]; then base="$(cat "$settings")"; else base="{}"; fi
        if printf '%s' "$base" | ${pkgs.jq}/bin/jq ${lib.escapeShellArg defaultsProg} > "$settings.nix.tmp"; then
          $DRY_RUN_CMD mv -- "$settings.nix.tmp" "$settings"
        else
          rm -f "$settings.nix.tmp"
          echo "prime-agent: jq merge failed for $settings (left unchanged)" >&2
        fi
      '';
    };
}
