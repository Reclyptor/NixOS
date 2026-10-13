_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (
        final: _prev:
        let
          # vLLM's OpenAI-compatible endpoint on the LAN (shared Cilium IP).
          baseUrl = "http://192.168.1.120:8000/v1";

          # vLLM runs without --api-key, so it checks no bearer at all, but some
          # OpenAI clients refuse to build a request without one. Not a secret.
          placeholderKey = "unused-vllm-runs-keyless";
        in
        {
          # The self-hosted vLLM endpoint's model catalog, read from its owner.
          # Every harness that routes to it needs the same fact — which models are
          # served, at what window — and each copy spelled by hand has drifted, so
          # this is the one place that asks the endpoint and checks the answer.
          # Sinks decide what a failure means for them; this only reports it.
          #
          # Prints `[{"id": …, "contextWindow": …}]` and exits 0, or names the
          # reason on stderr and exits 1: unreachable, unreadable, empty, or an
          # entry without an id or a positive max_model_len.
          vllm-catalog = final.writeShellApplication {
            name = "vllm-catalog";

            runtimeInputs = with final; [
              curl
              jq
            ];

            # Exposed so every sink routes to the same endpoint this fetch asks,
            # and any that needs a key sends the same placeholder.
            passthru = { inherit baseUrl placeholderKey; };

            text = ''
              fail() {
                echo "vllm-catalog: $1" >&2
                exit 1
              }

              if ! body="$(curl -sS --fail --max-time 8 "${baseUrl}/models" 2>/dev/null)"; then
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
