_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (
        final: _prev:
        let
          # vLLM's OpenAI-compatible endpoint on the LAN (shared Cilium IP). Not
          # a secret, unlike the remote endpoint's URL, which lives in sops.
          baseUrl = "http://192.168.1.120:8000/v1";

          # Neither endpoint checks the bearer: the LAN vLLM runs without
          # --api-key, and the remote one is authenticated by the Cloudflare
          # Access in front of it. But the remote vLLM refuses a request that
          # carries none, and so do some OpenAI clients. Not a secret.
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
          #   vllm-catalog                                         the LAN endpoint
          #   vllm-catalog <base-url-file> <cf-id-file> <cf-secret-file>
          #                                                        the remote one
          #
          # Prints `[{"id": …, "contextWindow": …}]` and exits 0, or names the
          # reason on stderr and exits 1: unreadable files, unreachable,
          # unreadable body, empty, or an entry without an id or a positive
          # max_model_len. The whole request reaches curl as a config on stdin,
          # so neither the remote URL nor the Access credentials ever appear in
          # argv, where /proc/*/cmdline would publish them.
          vllm-catalog = final.writeShellApplication {
            name = "vllm-catalog";

            runtimeInputs = with final; [
              coreutils
              curl
              jq
            ];

            # Exposed so every LAN sink routes to the same endpoint this fetch
            # asks, and every sink sends the same placeholder.
            passthru = { inherit baseUrl placeholderKey; };

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

              case "$#" in
                0)
                  endpoint="LAN"
                  config=("url = $(quote "${baseUrl}/models")")
                  ;;
                3)
                  endpoint="remote"
                  for f in "$@"; do
                    [ -r "$f" ] || fail "$f is not readable"
                  done
                  config=(
                    "url = $(quote "$(cat "$1")/models")"
                    "header = $(quote "CF-Access-Client-Id: $(cat "$2")")"
                    "header = $(quote "CF-Access-Client-Secret: $(cat "$3")")"
                  )
                  ;;
                *)
                  echo "usage: vllm-catalog [<base-url-file> <cf-id-file> <cf-secret-file>]" >&2
                  exit 2
                  ;;
              esac
              config+=("header = $(quote "Authorization: Bearer ${placeholderKey}")")

              if ! body="$(printf '%s\n' "''${config[@]}" |
                curl -sS --fail --max-time 8 --config - 2>/dev/null)"; then
                fail "$endpoint vllm endpoint unreachable"
              fi

              if ! catalog="$(printf '%s' "$body" | jq -c \
                '[.data[] | {"id": .id, "contextWindow": .max_model_len}]' 2>/dev/null)"; then
                fail "$endpoint vllm /models returned a body this cannot read"
              fi

              printf '%s' "$catalog" | jq -e 'length > 0' > /dev/null ||
                fail "$endpoint vllm /models listed no models"
              printf '%s' "$catalog" | jq -e \
                'all((.id // "" | length) > 0 and (.contextWindow // 0) > 0)' > /dev/null ||
                fail "$endpoint vllm /models listed an entry with no id or no positive max_model_len"

              printf '%s\n' "$catalog"
            '';
          };
        }
      )
    ];
  };
}
