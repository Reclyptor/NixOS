_: {
  flake.modules.homeManager.base =
    {
      lib,
      pkgs,
      ...
    }:
    let
      # The Codex half of the same pair — plan capacity left, per limit window,
      # everything on the pill and no tooltip.
      #
      # chatgpt.com sits behind bot protection that serves an HTML challenge —
      # with HTTP 200 — to anything that does not look like the CLI. The
      # originator, version and User-Agent headers together are what get a JSON
      # answer, so the version is taken from the codex package rather than
      # written out here: a bump moves both at once.
      #
      # Windows are reported as primary/secondary rather than by name, each
      # carrying its own duration, so the labels ("5h", "7d", "30d") are derived
      # from that duration. A plan with a different cadence labels itself
      # correctly instead of lying. Two field spellings exist in the wild — the
      # live endpoint says primary_window/limit_window_seconds/reset_at, the
      # records Codex writes to disk say primary/window_minutes/resets_at — and
      # both are accepted.
      #
      # Live or nothing, same as the Claude pill. Codex's access token is only
      # refreshed by `codex` itself, so "--" between sessions is expected; this
      # deliberately does not refresh it, because a second writer to auth.json
      # would race the CLI.
      #
      # The token goes to curl by --config on stdin, never argv:
      # /proc/<pid>/cmdline is world-readable and this is a live credential.
      usage = pkgs.writeShellApplication {
        name = "waybar-codex-usage";

        runtimeInputs = with pkgs; [
          curl
          jq
        ];

        text = ''
          body=null
          auth="$HOME/.codex/auth.json"

          if [ -r "$auth" ]; then
            tok="$(jq -r '.tokens.access_token // empty' "$auth" 2>/dev/null || true)"
            acc="$(jq -r '.tokens.account_id // empty' "$auth" 2>/dev/null || true)"
            if [ -n "$tok" ]; then
              got="$(printf 'header = "Authorization: Bearer %s"\nheader = "chatgpt-account-id: %s"\nheader = "originator: codex_cli_rs"\nheader = "version: %s"\nheader = "User-Agent: codex_cli_rs/%s"\nheader = "Accept: application/json"\n' \
                  "$tok" "$acc" "${pkgs.codex.version}" "${pkgs.codex.version}" \
                | curl -sf --max-time 10 --config - https://chatgpt.com/backend-api/codex/usage 2>/dev/null || true)"

              # The challenge page is HTML behind a 200, so --fail does not
              # catch it. Anything that is not JSON is treated as no answer.
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

            def window: if type != "number" or . <= 0 then "?"
                        elif . < 86400 then "\(. / 3600 | round)h"
                        else "\(. / 86400 | round)d" end;

            def win: if type != "object" or (has("used_percent") | not) then empty
                     else { l: ((.limit_window_seconds // ((.window_minutes // 0) * 60)) | window)
                          , p: .used_percent
                          , r: (.reset_at // .resets_at)
                          } end;

            def primary: .primary_window // .primary;

            # The rate-limit block is located by shape rather than by a fixed
            # path, so a reshaped payload degrades to "--" instead of to a
            # wrong number.
            ( [ $u | .. | objects
                | select((primary | type) == "object" and (primary | has("used_percent"))) ]
              | first ) as $rl

            | [ $rl | primary, (.secondary_window // .secondary) | win ] as $rows

            # Two spaces after the mark: these Codicons are single-width, so
            # they follow the cpu and memory pills rather than the
            # double-width md- glyphs on disk and bluetooth.
            | if ($rows | length) == 0
              then { text: "  --", class: "unavailable" }
              else { text: ("  " + ([ $rows[]
                     | "\(.l) \(.p | left)" + ((.r | at) as $w | if $w == "" then "" else " " + $w end)
                     ] | join("  ·  "))) }
              end
          '
        '';

        meta = {
          description = "Report remaining Codex plan capacity for a waybar pill";
          mainProgram = "waybar-codex-usage";
        };
      };
    in
    {
      programs.waybar.settings.mainBar."custom/codex-usage" = {
        format = "{}";
        return-type = "json";
        exec = "${lib.getExe usage}";
        on-click = "kitty --class codeburn -e codeburn";
        tooltip = false;
        interval = 120;
      };
    };
}
