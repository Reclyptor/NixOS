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

      # The two DeepSeek routes dsh has, as Prime Agent providers. models.json is
      # read by Prime Agent and never written by it, but a user may still add
      # providers of their own, so only these keys are owned; everything else in
      # the file — including anything else inside these two entries, such as
      # modelOverrides — is carried through.
      #
      # vllm: the endpoint is keyless, but the validator rejects a provider
      # that defines models without an apiKey, so it gets the catalog
      # fetcher's placeholder. headers is deleted rather than carried through:
      # it held the Cloudflare Access credential back when Access fronted the
      # endpoint, and nothing should send that to a plain-HTTP LAN host. No
      # compat and no `reasoning`: the endpoint thinks by default and only
      # honors `chat_template_kwargs.thinking`, which none of Prime Agent's
      # thinking formats send — declaring one would add a toggle that does
      # nothing. Reasoning still surfaces; the transport reads
      # reasoning_content for every model. models is only replaced by a
      # validated catalog, so an outage keeps the one already there, which is
      # why the file is rendered at runtime rather than through the store.
      #
      # deepseek: the built-in provider, so only its key is supplied — as a
      # command Prime Agent runs when it needs it, which keeps the key itself
      # off disk. baseUrl restates the built-in default because the validator
      # rejects a provider entry that carries only a key, and one invalid entry
      # discards the whole file.
      providersProg = ''
        .providers.vllm = ((.providers.vllm // {} | del(.headers)) + {
          name: "vLLM (self-hosted)",
          api: "openai-completions",
          baseUrl: "${pkgs.vllm-catalog.baseUrl}",
          apiKey: "${pkgs.vllm-catalog.placeholderKey}"
        }) |
        if env.PA_VLLM_CATALOG != "" then .providers.vllm.models = (env.PA_VLLM_CATALOG | fromjson) else . end |
        .providers.deepseek = ((.providers.deepseek // {}) + {
          baseUrl: "https://api.deepseek.com",
          apiKey: "!cat ${secretsDir}/deepseek-api-key"
        })
      '';

      # In a user unit rather than home.activation so no activation stalls on
      # the catalog fetch when the endpoint is down, and so a login refreshes
      # the catalog without waiting for a rebuild. Nothing here waits on sops:
      # the deepseek key is read by Prime Agent itself on use, so its absence
      # just leaves that provider unauthenticated until sops installs it.
      # umask makes the temp file 0600 and the rename keeps it, so no reader
      # ever sees the file half-written or world-readable.
      providersSync = pkgs.writeShellScript "prime-agent-providers-sync" ''
        set -eu
        umask 077

        if ! catalog="$(${lib.getExe pkgs.vllm-catalog})"; then
          echo "prime-agent: keeping the vllm models already in ${modelsFile}" >&2
          catalog=""
        fi

        mkdir -p "$(dirname "${modelsFile}")"
        if [ -f "${modelsFile}" ]; then base="$(cat "${modelsFile}")"; else base="{}"; fi

        if printf '%s' "$base" |
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
          Description = "Render Prime Agent's DeepSeek providers and vllm catalog";
        };

        Service = {
          Type = "oneshot";
          ExecStart = toString providersSync;
        };

        Install.WantedBy = [ "default.target" ];
      };
    };
}
