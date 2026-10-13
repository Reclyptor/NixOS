_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (
        final: _prev:
        let
          # vLLM refuses a request without a bearer but does not check it;
          # Cloudflare Access in front does the authenticating. Not a secret.
          placeholderKey = "unused-cloudflare-access-fronts-this";
        in
        {
          # The self-hosted vLLM endpoint's model catalog, read from its owner.
          # Every harness that routes to it needs the same fact — which models are
          # served, at what window — and each copy spelled by hand has drifted, so
          # this is the one place that asks the endpoint and checks the answer.
          # Sinks decide what a failure means for them; this only reports it.
          #
          #   vllm-catalog <cf-id-file> <cf-secret-file> <base-url-file>
          #
          # Prints `[{"id": …, "contextWindow": …}]` and exits 0, or names the
          # reason on stderr and exits 1: unreachable, unreadable, empty, or an
          # entry without an id or a positive max_model_len. Credentials are read
          # from the files and handed to curl on stdin, never in argv where
          # /proc/*/cmdline would publish them.
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
              [ "$#" -eq 3 ] || {
                echo "usage: vllm-catalog <cf-id-file> <cf-secret-file> <base-url-file>" >&2
                exit 2
              }

              fail() {
                echo "vllm-catalog: $1" >&2
                exit 1
              }

              if ! body="$(printf 'CF-Access-Client-Id: %s\nCF-Access-Client-Secret: %s\nAuthorization: Bearer %s\n' \
                "$(cat "$1")" "$(cat "$2")" "${placeholderKey}" |
                curl -sS --fail --max-time 8 -H @- "$(cat "$3")/models" 2>/dev/null)"; then
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
