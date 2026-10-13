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

      # Prime Agent owns ~/.prime/agent/settings.json — /model, /login, /factory
      # and the settings menu all write it — so Nix only fills in defaults that
      # are still unset and never overrides a choice made in-app.
      #
      # Provider and model travel together: a model id is only meaningful for
      # its provider. The pin matters because Prime Agent's own anthropic
      # default lags the current Opus.
      #
      # The factory (rlm.factory) ships off; here it defaults on. /factory off
      # writes an explicit false, which `== null` leaves alone where `//` would
      # not. Prime Agent reads it at client start.
      defaultsProg = ''
        (if .defaultProvider == null
         then .defaultProvider = "anthropic" | .defaultModel = "claude-opus-5-5"
         else .
         end) |
        if .factory.enabled == null then .factory.enabled = true else . end
      '';

      # The DeepSeek routes dsh has, as Prime Agent providers. models.json is
      # read by Prime Agent and never written by it, but a user may still add
      # providers of their own, so only these keys are owned; everything else in
      # the file — including anything else inside these entries, such as
      # modelOverrides — is carried through.
      #
      # vllm, the LAN endpoint: keyless, but the validator rejects a provider
      # that defines models without an apiKey, so it gets the catalog
      # fetcher's placeholder. headers is deleted rather than carried through:
      # the Cloudflare Access credential belongs to vllm-remote alone, an
      # older render left it here, and nothing should send it to a
      # plain-HTTP LAN host.
      #
      # vllm-remote, the Cloudflare-fronted endpoint: headers and baseUrl are
      # sent literally (only apiKey gets `!cmd` or env indirection), so the
      # Access secret has to be in the file itself. That is why the file is
      # rendered here at 0600 from sops at runtime rather than through the
      # world-readable store. Until the secrets exist the entry is left as it
      # is, or absent.
      #
      # Neither vLLM route declares compat or `reasoning`: both endpoints
      # think by default and only honor `chat_template_kwargs.thinking`, which
      # none of Prime Agent's thinking formats send — declaring one would add
      # a toggle that does nothing. Reasoning still surfaces; the transport
      # reads reasoning_content for every model. Each route's models are only
      # replaced by a validated catalog of its own, so an outage keeps the one
      # already there and never touches the other route's.
      #
      # deepseek: the built-in provider, so only its key is supplied — as a
      # command Prime Agent runs when it needs it, which keeps the key itself
      # off disk. baseUrl restates the built-in default because the validator
      # rejects a provider entry that carries only a key, and one invalid entry
      # discards the whole file.
      providersProg = ''
        .providers.vllm = ((.providers.vllm // {} | del(.headers)) + {
          name: "vLLM (LAN)",
          api: "openai-completions",
          baseUrl: "${pkgs.vllm-catalog.baseUrl}",
          apiKey: "${pkgs.vllm-catalog.placeholderKey}"
        }) |
        if env.PA_VLLM_CATALOG != "" then .providers.vllm.models = (env.PA_VLLM_CATALOG | fromjson) else . end |
        if env.PA_REMOTE_URL != "" then
          .providers["vllm-remote"] = ((.providers["vllm-remote"] // {}) + {
            name: "vLLM (remote)",
            api: "openai-completions",
            baseUrl: env.PA_REMOTE_URL,
            apiKey: "${pkgs.vllm-catalog.placeholderKey}",
            headers: {
              "CF-Access-Client-Id": env.PA_CF_ID,
              "CF-Access-Client-Secret": env.PA_CF_SECRET
            }
          })
        else . end |
        if env.PA_REMOTE_CATALOG != "" then .providers["vllm-remote"].models = (env.PA_REMOTE_CATALOG | fromjson) else . end |
        .providers.deepseek = ((.providers.deepseek // {}) + {
          baseUrl: "https://api.deepseek.com",
          apiKey: "!cat ${secretsDir}/deepseek-api-key"
        })
      '';

      # In a user unit rather than home.activation for the reason dsh's sync
      # is: sops-nix.service installs the vllm-remote secrets after every
      # activation entry has already run. It also means no activation stalls
      # on a catalog fetch when an endpoint is down, and a login refreshes the
      # catalogs without waiting for a rebuild. The deepseek key does not gate
      # anything: Prime Agent reads it itself on use, so its absence just
      # leaves that provider unauthenticated until sops installs it. umask
      # makes the temp file 0600 and the rename keeps it, so no reader ever
      # sees the file half-written or world-readable.
      providersSync = pkgs.writeShellScript "prime-agent-providers-sync" ''
        set -eu
        umask 077

        vllm_catalog=${lib.getExe pkgs.vllm-catalog}

        if ! lan_catalog="$("$vllm_catalog")"; then
          echo "prime-agent: keeping the vllm models already in ${modelsFile}" >&2
          lan_catalog=""
        fi

        # The remote URL and Access credentials reach jq through the
        # environment, never argv, where /proc/*/cmdline would expose them.
        remote_url_file="${secretsDir}/vllm-base-url"
        cf_id_file="${secretsDir}/cf-access-client-id"
        cf_secret_file="${secretsDir}/cf-access-client-secret"
        remote_url="" cf_id="" cf_secret="" remote_catalog=""

        if [ -f "$remote_url_file" ] && [ -f "$cf_id_file" ] && [ -f "$cf_secret_file" ]; then
          if ! remote_catalog="$("$vllm_catalog" "$remote_url_file" "$cf_id_file" "$cf_secret_file")"; then
            echo "prime-agent: keeping the vllm-remote models already in ${modelsFile}" >&2
            remote_catalog=""
          fi
          remote_url="$(cat "$remote_url_file")"
          cf_id="$(cat "$cf_id_file")"
          cf_secret="$(cat "$cf_secret_file")"
        else
          echo "prime-agent: vllm-remote secrets not present yet, keeping that provider as it is in ${modelsFile}" >&2
        fi

        mkdir -p "$(dirname "${modelsFile}")"
        if [ -f "${modelsFile}" ]; then base="$(cat "${modelsFile}")"; else base="{}"; fi

        if printf '%s' "$base" |
          PA_VLLM_CATALOG="$lan_catalog" \
          PA_REMOTE_CATALOG="$remote_catalog" \
          PA_REMOTE_URL="$remote_url" \
          PA_CF_ID="$cf_id" \
          PA_CF_SECRET="$cf_secret" \
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
          Description = "Render Prime Agent's DeepSeek and vllm providers from sops secrets";
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
