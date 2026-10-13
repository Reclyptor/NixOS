_: {
  flake.modules.homeManager.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      secretsDir = "${config.home.homeDirectory}/.config/sops/secrets/bash";
      modelsFile = "${config.home.homeDirectory}/.prime/agent/models.json";

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

      # The two DeepSeek routes dsh has, as Prime Agent providers. models.json is
      # read by Prime Agent and never written by it, but a user may still add
      # providers of their own, so only these keys are owned; everything else in
      # the file — including anything else inside these two entries, such as
      # modelOverrides — is carried through.
      #
      # vllm: headers and baseUrl are sent literally (only apiKey gets `!cmd` or
      # env indirection), so the Cloudflare Access secret has to be in the file
      # itself. That is why the file is rendered here at 0600 from sops at
      # runtime rather than through the world-readable store. No compat and no
      # `reasoning`: the endpoint thinks by default and only honors
      # `chat_template_kwargs.thinking`, which none of Prime Agent's thinking
      # formats send — declaring one would add a toggle that does nothing.
      # Reasoning still surfaces; the transport reads reasoning_content for
      # every model. models is only replaced by a validated catalog, so an
      # outage keeps the one already there.
      #
      # deepseek: the built-in provider, so only its key is supplied — as a
      # command Prime Agent runs when it needs it, which keeps the key itself
      # off disk. baseUrl restates the built-in default because the validator
      # rejects a provider entry that carries only a key, and one invalid entry
      # discards the whole file.
      providersProg = ''
        .providers.vllm = ((.providers.vllm // {}) + {
          name: "vLLM (self-hosted)",
          api: "openai-completions",
          baseUrl: env.PA_VLLM_URL,
          apiKey: "${pkgs.vllm-catalog.placeholderKey}",
          headers: {
            "CF-Access-Client-Id": env.PA_CF_ID,
            "CF-Access-Client-Secret": env.PA_CF_SECRET
          }
        }) |
        if env.PA_VLLM_CATALOG != "" then .providers.vllm.models = (env.PA_VLLM_CATALOG | fromjson) else . end |
        .providers.deepseek = ((.providers.deepseek // {}) + {
          baseUrl: "https://api.deepseek.com",
          apiKey: "!cat ${secretsDir}/deepseek-api-key"
        })
      '';

      # In a user unit rather than home.activation for the reason dsh's sync is:
      # sops-nix.service installs the secrets after every activation entry has
      # already run. umask makes the temp file 0600 and the rename keeps it, so
      # no reader ever sees the file half-written or world-readable.
      providersSync = pkgs.writeShellScript "prime-agent-providers-sync" ''
        set -eu
        umask 077

        id_file="${secretsDir}/cf-access-client-id"
        secret_file="${secretsDir}/cf-access-client-secret"
        url_file="${secretsDir}/vllm-base-url"

        # Only the vllm secrets gate the render: the deepseek key is read by
        # Prime Agent itself on use, so its absence just leaves that provider
        # unauthenticated until sops installs it.
        for f in "$id_file" "$secret_file" "$url_file"; do
          if [ ! -f "$f" ]; then
            echo "prime-agent: $f not present yet, skipping ${modelsFile}" >&2
            exit 0
          fi
        done

        if ! catalog="$(${lib.getExe pkgs.vllm-catalog} "$id_file" "$secret_file" "$url_file")"; then
          echo "prime-agent: keeping the vllm models already in ${modelsFile}" >&2
          catalog=""
        fi

        mkdir -p "$(dirname "${modelsFile}")"
        if [ -f "${modelsFile}" ]; then base="$(cat "${modelsFile}")"; else base="{}"; fi

        if printf '%s' "$base" |
          PA_CF_ID="$(cat "$id_file")" \
          PA_CF_SECRET="$(cat "$secret_file")" \
          PA_VLLM_URL="$(cat "$url_file")" \
          PA_VLLM_CATALOG="$catalog" \
          ${lib.getExe pkgs.jq} ${lib.escapeShellArg providersProg} > "${modelsFile}.tmp"; then
          mv -f "${modelsFile}.tmp" "${modelsFile}"
        else
          rm -f "${modelsFile}.tmp"
          echo "prime-agent: jq merge failed for ${modelsFile} (left unchanged)" >&2
        fi
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

      systemd.user.services.prime-agent-providers-sync = {
        Unit = {
          Description = "Render Prime Agent's DeepSeek providers from sops secrets";
          Wants = [ "sops-nix.service" ];
          After = [ "sops-nix.service" ];
        };

        Service = {
          Type = "oneshot";
          ExecStart = toString providersSync;
        };

        Install.WantedBy = [ "default.target" ];
      };
    };
}
