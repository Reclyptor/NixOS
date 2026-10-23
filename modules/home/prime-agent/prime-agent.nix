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
      settingsFile = "${config.home.homeDirectory}/.prime/agent/settings.json";
      routes = config.vllm.routes;
      renames = builtins.toJSON config.vllm.renames;
      behindAccess = r: r.accessClientIdFile != null;
      # The files a route's render reads: its URL, plus the Access token for
      # a route behind Cloudflare.
      routeFiles =
        r:
        [ r.baseUrlFile ]
        ++ lib.optionals (behindAccess r) [
          r.accessClientIdFile
          r.accessClientSecretFile
        ];

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
      #
      # Compaction is only checked when a run starts or ends, never between the
      # tool calls inside one — even an agent's own compact.run() waits for the
      # run to end — so a long run can grow straight past the threshold into
      # the context limit. The overflow recovery then has to summarize the
      # run's opening as one cold prompt. Nothing here can stop that; the
      # threshold only buys headroom. Compacting at 128k of Qwen's 256k window
      # (reserveTokens) leaves a run about 115k to grow before it overflows
      # (a run has been seen to grow 97k), and keeping 40k recent tokens
      # verbatim keeps the recovery prompt to about 90k. Each field is filled
      # separately, so a value set in-app stays; 81920 was this module's
      # previous default rather than anyone's choice, so it moves too.
      #
      # Every saved reference to a route's former id moves to its current one:
      # the default provider, and the "provider/model" strings or
      # {provider, model} objects of the model lists and slots (recentModels
      # feeds the /model picker). Model ids belong to the route, so they stay.
      #
      # The model picker's scope (enabledModels) defaults to this machine's
      # own models: the self-hosted routes as whole-provider globs (the app
      # expands them at session creation against the live catalogs, so a model
      # an endpoint newly serves appears without a Nix change), plus official
      # DeepSeek's two models and the current latest of each Anthropic and
      # Codex flagship line pinned by id. The pins are exact because a bare
      # provider glob also matches other providers' slashed ids (openrouter's
      # and vercel's DeepSeek models carry ids like "deepseek/deepseek-v4-flash"),
      # which would leak into the scope; globs cannot express "latest" anyway,
      # and a pinned id is a one-line bump when a newer model ships. Filled
      # only while null, so a scope chosen in-app wins. The daemon's
      # allowedModels gate stays unset: it fails closed and would hard-refuse
      # stale references rather than hide them from the picker.
      defaultsProg = ''
        ${renames} as $ren |
        def moved:
          if type == "string" then
            split("/") as $parts |
            if ($parts | length) > 1 and ($ren | has($parts[0]))
            then [$ren[$parts[0]]] + $parts[1:] | join("/")
            else . end
          elif type == "object" then
            .provider as $p |
            if ($p | type) == "string" and ($ren | has($p)) then .provider = $ren[$p] else . end
          else . end;
        (.defaultProvider as $p |
         if $p != null and ($ren | has($p)) then .defaultProvider = $ren[$p] else . end) |
        reduce ("recentModels", "enabledModels", "allowedModels") as $k (.;
          if (.[$k] | type) == "array" then .[$k] |= (map(moved) | . as $l | reduce $l[] as $m ([]; if index([$m]) then . else . + [$m] end)) else . end) |
        reduce ("auxiliaryModel", "imageModel", "providerBackupModel", "subagentDefaultModel") as $k (.;
          if .[$k] != null then .[$k] |= moved else . end) |
        (if .defaultProvider == null
         then .defaultProvider = "anthropic" | .defaultModel = "claude-opus-5-5"
         else .
         end) |
        (if .compaction.reserveTokens == null or .compaction.reserveTokens == 81920
         then .compaction.reserveTokens = 131072
         else .
         end) |
        (if .compaction.keepRecentTokens == null then .compaction.keepRecentTokens = 40000 else . end) |
        (if .enabledModels == null
         then .enabledModels = [
           "deepseek-self-hosted/*",
           "qwen-cloudflare/*",
           "qwen-lan/*",
           "deepseek/deepseek-flash",
           "deepseek/deepseek-v4-pro",
           "anthropic/claude-opus-5-5",
           "anthropic/claude-sonnet-5-5",
           "anthropic/claude-haiku-4-5",
           "openai-codex/gpt-6-astra",
           "openai-codex/gpt-6-luna",
           "openai-codex/gpt-5.6-terra",
           "openai-codex/gpt-6.1-sol"
         ]
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
      # Every Prime Agent thinking format for openai-completions sends
      # `reasoning_effort`, and the vLLM endpoints honor it, so a route that
      # lists its reasoningEfforts marks each model as reasoning, with a
      # thinkingLevelMap that names only the efforts the endpoint accepts.
      # Prime Agent offers just those levels and clamps a setting it has no
      # entry for to the nearest one, so it never sends a value the chat
      # template would reject. `off` is `none`. Each route's models are only
      # replaced by a validated catalog of its own, so an outage keeps the
      # ones already there and never touches another route's; the map is
      # applied to whichever set survives.
      # deepseek: the built-in provider, so only its key is supplied — as a
      # command Prime Agent runs when it needs it, which keeps the key itself
      # off disk. baseUrl restates the built-in default because the validator
      # rejects a provider entry that carries only a key, and one invalid entry
      # discards the whole file.
      thinkingLevels = [
        "minimal"
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
      thinkingLevelMap =
        efforts:
        let
          ifAccepted = effort: if lib.elem effort efforts then effort else null;
        in
        { off = ifAccepted "none"; } // lib.genAttrs thinkingLevels ifAccepted;

      routeProg =
        id: r:
        let
          key = builtins.toJSON id;
          env = "env.PA_${r.envName}";
          reasoning = builtins.toJSON {
            reasoning = true;
            thinkingLevelMap = thinkingLevelMap r.reasoningEfforts;
          };
        in
        ''
          if ${env}_URL != "" then
            .providers[${key}] = ((.providers[${key}] // {}) + {
              name: ${builtins.toJSON r.displayName},
              api: "openai-completions",
              baseUrl: ${env}_URL,
              apiKey: "${pkgs.vllm-catalog.placeholderKey}"${lib.optionalString (behindAccess r) ''
                ,
                              headers: {
                                "CF-Access-Client-Id": ${env}_ACCESS_ID,
                                "CF-Access-Client-Secret": ${env}_ACCESS_SECRET
                              }''}
            }) |
            if ${env}_CATALOG != "" then .providers[${key}].models = (${env}_CATALOG | fromjson) else . end${
              lib.optionalString (
                r.reasoningEfforts != [ ]
              ) " |
  .providers[${key}].models |= map(. + ${reasoning})"
            }
          else . end |
        '';

      # Entries under a route's former ids are dropped first: a renamed route
      # would otherwise show up twice, once under a key nothing refreshes.
      providersProg = ''
        .providers |= del(.[(${renames} | keys)[]]) |
        ${lib.concatStrings (lib.mapAttrsToList routeProg routes)}
        .providers.deepseek = ((.providers.deepseek // {}) + {
          baseUrl: "https://api.deepseek.com",
          apiKey: "!cat ${secretsDir}/deepseek-api-key",
          # The official API renamed deepseek-v4-flash to deepseek-flash
          # (verified 2026-10-20 against the live /models endpoint) while the
          # app's catalog still lists the old id; declare the renamed model
          # with that catalog entry's metadata, since the merge replaces a
          # matching provider+id wholesale. deepseek-v4-pro keeps resolving
          # from the catalog untouched.
          models: [
            {id: "deepseek-flash",
             name: "DeepSeek Flash",
             reasoning: true,
             thinkingLevelMap: {off: null, minimal: null, low: null, medium: null, high: "high", xhigh: "max", max: null},
             input: ["text", "image"],
             cost: {input: 0.15, output: 0.6, cacheRead: 0.003, cacheWrite: 0},
             contextWindow: 1000000,
             maxTokens: 393216,
             compat: {requiresReasoningContentOnAssistantMessages: true, thinkingFormat: "deepseek"}}
          ]
        })
      '';

      pruneRecentsProg = ''
        ($models[0].providers // {}) as $providers |
        if (.recentModels | type) == "array" then
          .recentModels |= map(select(
            (type != "string") or
            (split("/") as $parts |
             ($parts | length) < 2 or
             ($routes | any(. == $parts[0]) | not) or
             (($providers[$parts[0]].models | type) != "array") or
             ($providers[$parts[0]].models | any(.id == ($parts[1:] | join("/")))))))
        else . end
      '';

      # Fetches one route's catalog and reads its URL and Access credentials
      # into route_<id>_* shell variables, kept apart from the script's own
      # names (a route named vllm would clobber $vllm_catalog). They reach jq
      # through the environment, never argv, where /proc/*/cmdline would
      # expose them.
      fetchRoute =
        id: r:
        let
          v = "route_${lib.toLower r.envName}";
          files = routeFiles r;
        in
        ''
          ${v}_url="" ${v}_access_id="" ${v}_access_secret="" ${v}_catalog=""

          if ${lib.concatMapStringsSep " && " (f: "[ -f ${lib.escapeShellArg f} ]") files}; then
            if ! ${v}_catalog="$("$vllm_catalog" ${lib.escapeShellArgs (files ++ [ (toString r.contextWindow) ])})"; then
              echo "prime-agent: keeping the ${id} models already in ${modelsFile}" >&2
              ${v}_catalog=""
            fi
            ${v}_url="$(cat ${lib.escapeShellArg r.baseUrlFile})"
            ${lib.optionalString (behindAccess r) ''
              ${v}_access_id="$(cat ${lib.escapeShellArg r.accessClientIdFile})"
              ${v}_access_secret="$(cat ${lib.escapeShellArg r.accessClientSecretFile})"
            ''}
          else
            echo "prime-agent: ${id} secrets not present yet, keeping that provider as it is in ${modelsFile}" >&2
          fi
        '';

      routeEnv =
        _id: r:
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

        # The /model picker's recent list outlives what a route serves: an
        # entry naming a self-hosted route and a model that route no longer
        # lists (its catalog changed, or a rename carried an old pairing
        # across) is dropped. Only route entries with a model list are
        # judged; the file is rewritten only when something goes.
        if [ -f "${settingsFile}" ] && [ -f "${modelsFile}" ]; then
          if ${lib.getExe pkgs.jq} --slurpfile models "${modelsFile}" \
            --argjson routes ${lib.escapeShellArg (builtins.toJSON (lib.attrNames routes))} \
            ${lib.escapeShellArg pruneRecentsProg} "${settingsFile}" > "${settingsFile}.tmp"; then
            if cmp -s "${settingsFile}.tmp" "${settingsFile}"; then
              rm -f "${settingsFile}.tmp"
            else
              mv -f "${settingsFile}.tmp" "${settingsFile}"
            fi
          else
            rm -f "${settingsFile}.tmp"
            echo "prime-agent: could not prune recent models in ${settingsFile} (left unchanged)" >&2
          fi
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

      # Same cmp guard as providersSync's prune below: a switch whose merge
      # changes nothing must not rewrite the file under a running agent.
      home.activation.primeAgentSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings="$HOME/.prime/agent/settings.json"
        $DRY_RUN_CMD mkdir -p "$(dirname "$settings")"
        if [ -f "$settings" ]; then base="$(cat "$settings")"; else base="{}"; fi
        if printf '%s' "$base" | ${pkgs.jq}/bin/jq ${lib.escapeShellArg defaultsProg} > "$settings.nix.tmp"; then
          if cmp -s "$settings.nix.tmp" "$settings"; then
            rm -f "$settings.nix.tmp"
          else
            $DRY_RUN_CMD mv -- "$settings.nix.tmp" "$settings"
          fi
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
