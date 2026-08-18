_: {
  flake.modules.homeManager.base =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      secretsDir = "${config.home.homeDirectory}/.config/sops/secrets/bash";
      settingsFile = "${config.home.homeDirectory}/.dsh/settings.yaml";

      # Discovered from GET /models on the endpoint; max_model_len is 1048576.
      model = "deepseek-v4-flash-0731";
      contextWindow = 1048576;

      # Owned keys only. Everything else in settings.yaml — including anything
      # the web Models page writes — is left untouched, so this merge is safe to
      # re-run and does not fight the UI for ownership of the document.
      #
      # No `compat.thinkingFormat` and no `reasoningEfforts`: the endpoint
      # ignores DeepSeek's `thinking: {type: disabled}` and only responds to
      # `chat_template_kwargs`, which dsh's SUPPORTED_THINKING_FORMATS does not
      # expose. Declaring a format would render an effort toggle that silently
      # does nothing. Reasoning output still surfaces — pi-ai's response parser
      # scans reasoning_content/reasoning/reasoning_text regardless of format.
      program = ''
        .["llm-pi-ai"].providers.vllm.api = "openai-completions" |
        .["llm-pi-ai"].providers.vllm.displayName = "vLLM (DeepSeek V4 Flash)" |
        .["llm-pi-ai"].providers.vllm.baseURL = strenv(DSH_VLLM_URL) |
        .["llm-pi-ai"].providers.vllm.apiKeyEnv = "VLLM_API_KEY" |
        .["llm-pi-ai"].providers.vllm.defaultContextWindow = ${toString contextWindow} |
        .["llm-pi-ai"].providers.vllm.headers["CF-Access-Client-Id"] = strenv(DSH_CF_ID) |
        .["llm-pi-ai"].providers.vllm.headers["CF-Access-Client-Secret"] = strenv(DSH_CF_SECRET) |
        .["llm-pi-ai"].providers.vllm.models = [{"id": "${model}"}] |
        .["agent-default-model"].provider = "vllm" |
        .["agent-default-model"].model = "${model}"
      '';
    in
    {
      # pi-ai's OpenAI-compatible transport refuses to build a request without a
      # credential, but this endpoint is keyless — Cloudflare Access in front of
      # it does the authenticating, via the header pair below. Upstream's own
      # guidance for that case is a placeholder referenced by apiKeyEnv. It is
      # not a secret and deliberately does not come from sops.
      home.sessionVariables.VLLM_API_KEY = "unused-cloudflare-access-fronts-this";

      # settings.yaml is generated here rather than by home.file because it has
      # to carry the Cloudflare Access client secret in cleartext: dsh types
      # `headers` as a plain string dict, and only `apiKeyEnv` gets credential
      # indirection. home.file would place that secret in the world-readable
      # Nix store. Written at activation from the sops-decrypted files instead,
      # mode 0600, with the values passed through the environment (strenv) so
      # they never appear in argv where /proc/*/cmdline would expose them.
      #
      # Upstream caveat worth knowing: a credential in `headers` is returned
      # verbatim by a redacted describe() and rendered by the Models page. That
      # is a known limitation in llm-pi-ai, not something this config can avoid.
      home.activation.deepseekHarness = lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" ] ''
        dsh_id="${secretsDir}/cf-access-client-id"
        dsh_secret="${secretsDir}/cf-access-client-secret"
        dsh_url="${secretsDir}/vllm-base-url"

        if [ -f "$dsh_id" ] && [ -f "$dsh_secret" ] && [ -f "$dsh_url" ]; then
          $DRY_RUN_CMD mkdir -p "$(dirname "${settingsFile}")"
          [ -f "${settingsFile}" ] || $DRY_RUN_CMD touch "${settingsFile}"
          $DRY_RUN_CMD chmod 600 "${settingsFile}"

          if DSH_CF_ID="$(cat "$dsh_id")" \
             DSH_CF_SECRET="$(cat "$dsh_secret")" \
             DSH_VLLM_URL="$(cat "$dsh_url")" \
             ${lib.getExe pkgs.yq-go} -i '${program}' "${settingsFile}"; then
            :
          else
            echo "deepseek: yq merge failed for ${settingsFile} (left unchanged)" >&2
          fi
        else
          echo "deepseek: sops secrets not present yet, skipping settings.yaml" >&2
        fi
      '';
    };
}
