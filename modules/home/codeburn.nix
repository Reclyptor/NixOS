_: {
  flake.modules.homeManager.base =
    { lib, pkgs, ... }:
    let
      # Left alone, CodeBurn reports API-equivalent cost: what today's tokens
      # would have cost at pay-as-you-go rates. On a subscription that is a
      # burn-rate signal, not a bill. Declaring the plan turns it into
      # spend-against-plan and — more usefully — moves the monthly window off
      # the calendar and onto the real billing cycle, which is what the waybar
      # pill's tooltip reports.
      #
      # `setAt` is written by `codeburn plan set` but is not required to read a
      # plan back, so it is omitted rather than faked with a build-time date.
      #
      # No codex entry: Codex here is API-billed, so its raw cost already IS the
      # real number and a plan would only distort it. CodeBurn ships no Codex
      # preset either — it would have to be `plan set custom --provider codex`.
      claudePlan = {
        id = "claude-max"; # Claude Max 20x
        monthlyUsd = 200;
        provider = "claude";
        resetDay = 20;
      };

      # Assigns .plans.claude and nothing else. A jq merge rather than
      # home.file because CodeBurn owns the rest of this file — `codeburn
      # currency`, `model-alias`, `price-override`, `proxy-path`, and
      # `plan set` for any other provider all write into it, and a read-only
      # store symlink would break every one of those commands.
      planProg = ''
        .plans = (.plans // {})
        | .plans.claude = ${builtins.toJSON claudePlan}
      '';
    in
    {
      home.activation.codeburnPlan = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        config="$HOME/.config/codeburn/config.json"
        $DRY_RUN_CMD mkdir -p "$(dirname "$config")"
        if [ -f "$config" ]; then base="$(cat "$config")"; else base="{}"; fi
        if printf '%s' "$base" | ${lib.getExe pkgs.jq} ${lib.escapeShellArg planProg} > "$config.cb.tmp"; then
          $DRY_RUN_CMD mv -- "$config.cb.tmp" "$config"
        else
          rm -f "$config.cb.tmp"
          echo "codeburn: jq merge failed for $config (left unchanged)" >&2
        fi
      '';
    };
}
