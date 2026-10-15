_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (
        final: _prev:
        let
          # No endpoint checks the bearer: Cloudflare Access in front of each,
          # or the LAN itself, does the authenticating. But vLLM refuses a request that carries
          # none, and so do some OpenAI clients. Not a secret.
          placeholderKey = "unused-vllm-checks-no-key";
        in
        {
          # The self-hosted vLLM endpoints' model catalogs, read from their
          # owners. Every harness that routes to one needs the same fact — which
          # models are served, at what window — and each copy spelled by hand
          # has drifted, so this is the one place that asks an endpoint and
          # checks the answer. Sinks decide what a failure means for them; this
          # only reports it.
          #
          #   vllm-catalog <base-url-file> [<cf-id-file> <cf-secret-file>]
          #
          # The Access files are left off for a LAN route, which has nothing in
          # front of it.
          # Prints `[{"id": …, "contextWindow": …}]` and exits 0, or names the
          # reason on stderr and exits 1: unreadable files, unreachable,
          # unreadable body, empty, or an entry without an id or a positive
          # max_model_len. The whole request reaches curl as a config on stdin,
          # so neither the URL nor the Access credentials ever appear in argv,
          # where /proc/*/cmdline would publish them.
          vllm-catalog = final.writeShellApplication {
            name = "vllm-catalog";

            runtimeInputs = with final; [
              coreutils
              curl
              jq
            ];

            # Exposed so every sink sends the same placeholder this fetch does.
            passthru = { inherit placeholderKey; };

            text = ''
              fail() {
                echo "vllm-catalog: $1" >&2
                exit 1
              }

              # A curl config value, double-quoted with its escapes.
              quote() {
                local v="''${1//\\/\\\\}"
                printf '"%s"' "''${v//\"/\\\"}"
              }

              if [ "$#" -ne 1 ] && [ "$#" -ne 3 ]; then
                echo "usage: vllm-catalog <base-url-file> [<cf-id-file> <cf-secret-file>]" >&2
                exit 2
              fi
              for f in "$@"; do
                [ -r "$f" ] || fail "$f is not readable"
              done
              config=(
                "url = $(quote "$(cat "$1")/models")"
                "header = $(quote "Authorization: Bearer ${placeholderKey}")"
              )
              if [ "$#" -eq 3 ]; then
                config+=(
                  "header = $(quote "CF-Access-Client-Id: $(cat "$2")")"
                  "header = $(quote "CF-Access-Client-Secret: $(cat "$3")")"
                )
              fi

              if ! body="$(printf '%s\n' "''${config[@]}" |
                curl -sS --fail --max-time 8 --config - 2>/dev/null)"; then
                fail "vllm endpoint unreachable"
              fi

              if ! catalog="$(printf '%s' "$body" | jq -c \
                '[.data[] | {"id": .id, "contextWindow": .max_model_len}]' 2>/dev/null)"; then
                fail "vllm /models returned a body this cannot read"
              fi

              printf '%s' "$catalog" | jq -e 'length > 0' > /dev/null ||
                fail "vllm /models listed no models"
              printf '%s' "$catalog" | jq -e \
                'all((.id // "" | length) > 0 and (.contextWindow // 0) > 0)' > /dev/null ||
                fail "vllm /models listed an entry with no id or no positive max_model_len"

              printf '%s\n' "$catalog"
            '';
          };
        }
      )
    ];
  };
}
