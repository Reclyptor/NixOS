_: {
  flake.modules.homeManager.base =
    {
      lib,
      pkgs,
      ...
    }:
    let
      # Plan capacity left, per limit window — the same numbers Claude Code's
      # /usage panel draws bars for. Everything is on the pill; there is no
      # tooltip, so nothing about the quota requires a hover to discover.
      #
      # The endpoint is what Claude Code itself polls (its binary names the call
      # "fetchUtilization"). It is not contractual, so the payload is read
      # defensively: an unrecognised shape yields "--" rather than a wrong
      # number. Live or nothing — a remembered percentage reads as headroom
      # that may already be spent, which is worse than no reading at all.
      #
      # The token goes to curl by --config on stdin, never argv:
      # /proc/<pid>/cmdline is world-readable and this is a live credential.
      usage = pkgs.writeShellApplication {
        name = "waybar-claude-usage";

        runtimeInputs = with pkgs; [
          curl
          jq
        ];

        text = ''
          body=null
          creds="$HOME/.claude/.credentials.json"

          if [ -r "$creds" ]; then
            tok="$(jq -r '.claudeAiOauth.accessToken // empty' "$creds" 2>/dev/null || true)"
            if [ -n "$tok" ]; then
              got="$(printf 'header = "Authorization: Bearer %s"\nheader = "anthropic-beta: oauth-2025-04-20"\n' "$tok" \
                | curl -sf --max-time 10 --config - https://api.anthropic.com/api/oauth/usage 2>/dev/null || true)"

              # An interstitial or error page can arrive behind a 200, which
              # --fail does not catch. Anything that is not JSON is no answer.
              if printf '%s' "$got" | jq -e . >/dev/null 2>&1; then
                body="$got"
              fi
            fi
          fi

          jq -cn --argjson u "$body" '
            # The API reports percent USED; the pill reports what is left.
            def left: if type == "number" then ((100 - .) | round | tostring) + "%" else "--" end;

            def at: if type != "string" and type != "number" then ""
                    else ((if type == "string"
                           then (sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601)
                           else . end)
                          # The reset instant jitters below the minute, which
                          # would flip the displayed clock back and forth.
                          | (. / 60 | round) * 60) as $t
                       # Within a day the date is noise; within a week the
                       # weekday identifies it; beyond that only a date does.
                       | $t | strflocaltime(if ($t - now) < 86400 then "%H:%M"
                                            elif ($t - now) < 604800 then "%a %H:%M"
                                            else "%-d %b" end)
                    end;

            ($u.limits // []) as $L
            | ( [ $L[] | select(.kind == "session")    | {l: "5h", p: .percent, r: .resets_at} ]
              + [ $L[] | select(.kind == "weekly_all") | {l: "7d", p: .percent, r: .resets_at} ]
              + [ $L[] | select(.kind == "weekly_scoped")
                       | {l: (.scope.model.display_name // "scoped"), p: .percent, r: .resets_at} ]
              ) as $rows

            # Two spaces after the mark: these Codicons are single-width, so
            # they follow the cpu and memory pills rather than the
            # double-width md- glyphs on disk and bluetooth.
            | if ($rows | length) == 0
              then { text: "  --", class: "unavailable" }
              else { text: ("  " + ([ $rows[]
                     | "\(.l) \(.p | left)" + ((.r | at) as $w | if $w == "" then "" else " " + $w end)
                     ] | join("  ·  "))) }
              end
          '
        '';

        meta = {
          description = "Report remaining Claude plan capacity for a waybar pill";
          mainProgram = "waybar-claude-usage";
        };
      };
    in
    {
      # The bar's layout and styling stay in hypr/waybar.nix — this contributes
      # only the module itself, which merges into the same mainBar attrset.
      programs.waybar.settings.mainBar."custom/claude-usage" = {
        format = "{}";
        return-type = "json";
        exec = "${lib.getExe usage}";
        on-click = "kitty --class codeburn -e codeburn";
        tooltip = false;
        # One API call a tick against a 5-hour and a 7-day window. At 120s one
        # percent of the session window is still ~3 minutes of budget.
        interval = 120;
      };
    };
}
