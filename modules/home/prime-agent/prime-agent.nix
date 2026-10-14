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
      routes = config.vllm.routes;

      # A shell variable's expansion, double-quoted.
      shellRef = name: "\"\$${name}\"";

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
      # The vLLM routes are declared once in ../vllm-routes.nix and shared
      # with dsh. Each sits behind Cloudflare Access: headers and baseUrl are
      # sent literally (only apiKey gets `!cmd` or env indirection), so the
      # Access secret has to be in the file itself. That is why the file is
      # rendered here at 0600 from sops at runtime rather than through the
      # world-readable store. The endpoints check no bearer, but the
      # validator rejects a provider that defines models without an apiKey,
      # so each gets the catalog fetcher's placeholder. A route whose secrets
      # do not exist yet is left as it is, or absent.
      #
      # No vLLM route declares compat or `reasoning`: the endpoints think by
      # default and only honor `chat_template_kwargs.thinking`, which none of
      # Prime Agent's thinking formats send — declaring one would add a toggle
      # that does nothing. Reasoning still surfaces; the transport reads
      # reasoning_content for every model. Each route's models are only
      # replaced by a validated catalog of its own, so an outage keeps the one
      # already there and never touches another route's.
      #
      # deepseek: the built-in provider, so only its key is supplied — as a
      # command Prime Agent runs when it needs it, which keeps the key itself
      # off disk. baseUrl restates the built-in default because the validator
      # rejects a provider entry that carries only a key, and one invalid entry
      # discards the whole file.
      routeProg =
        id: r:
        let
          key = builtins.toJSON id;
          env = "env.PA_${r.envName}";
        in
        ''
          if ${env}_URL != "" then
            .providers[${key}] = ((.providers[${key}] // {}) + {
              name: ${builtins.toJSON r.displayName},
              api: "openai-completions",
              baseUrl: ${env}_URL,
              apiKey: "${pkgs.vllm-catalog.placeholderKey}",
              headers: {
                "CF-Access-Client-Id": ${env}_ACCESS_ID,
                "CF-Access-Client-Secret": ${env}_ACCESS_SECRET
              }
            }) |
            if ${env}_CATALOG != "" then .providers[${key}].models = (${env}_CATALOG | fromjson) else . end
          else . end |
        '';

      providersProg = ''
        ${lib.concatStrings (lib.mapAttrsToList routeProg routes)}
        .providers.deepseek = ((.providers.deepseek // {}) + {
          baseUrl: "https://api.deepseek.com",
          apiKey: "!cat ${secretsDir}/deepseek-api-key"
        })
      '';

      # Fetches one route's catalog and reads its URL and Access credentials
      # into route_<id>_* shell variables, kept apart from the script's own
      # names (route vllm would otherwise clobber $vllm_catalog). They reach jq
      # through the environment, never argv, where /proc/*/cmdline would
      # expose them.
      fetchRoute =
        id: r:
        let
          v = "route_${lib.toLower r.envName}";
        in
        ''
          ${v}_url="" ${v}_access_id="" ${v}_access_secret="" ${v}_catalog=""

          if [ -f ${lib.escapeShellArg r.baseUrlFile} ] &&
            [ -f ${lib.escapeShellArg r.accessClientIdFile} ] &&
            [ -f ${lib.escapeShellArg r.accessClientSecretFile} ]; then
            if ! ${v}_catalog="$("$vllm_catalog" ${
              lib.escapeShellArgs [
                r.baseUrlFile
                r.accessClientIdFile
                r.accessClientSecretFile
              ]
            })"; then
              echo "prime-agent: keeping the ${id} models already in ${modelsFile}" >&2
              ${v}_catalog=""
            fi
            ${v}_url="$(cat ${lib.escapeShellArg r.baseUrlFile})"
            ${v}_access_id="$(cat ${lib.escapeShellArg r.accessClientIdFile})"
            ${v}_access_secret="$(cat ${lib.escapeShellArg r.accessClientSecretFile})"
          else
            echo "prime-agent: ${id} secrets not present yet, keeping that provider as it is in ${modelsFile}" >&2
          fi
        '';

      routeEnv =
        id: r:
        let
          v = "route_${lib.toLower r.envName}";
          env = "PA_${r.envName}";
        in
        ''
          ${env}_URL=${shellRef "${v}_url"} \
          ${env}_ACCESS_ID=${shellRef "${v}_access_id"} \
          ${env}_ACCESS_SECRET=${shellRef "${v}_access_secret"} \
          ${env}_CATALOG=${shellRef "${v}_catalog"} \
        '';

      # In a user unit rather than home.activation for the reason dsh's sync
      # is: sops-nix.service installs the vLLM route secrets after every
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

        ${lib.concatStrings (lib.mapAttrsToList fetchRoute routes)}
        mkdir -p "$(dirname "${modelsFile}")"
        if [ -f "${modelsFile}" ]; then base="$(cat "${modelsFile}")"; else base="{}"; fi

        if printf '%s' "$base" |
          ${lib.concatStrings (lib.mapAttrsToList routeEnv routes)}  ${lib.getExe pkgs.jq} ${lib.escapeShellArg providersProg} > "${modelsFile}.tmp"; then
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
