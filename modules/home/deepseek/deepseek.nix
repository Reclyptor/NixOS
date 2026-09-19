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

      # The harness home's own environment layer. dsh reads it as the LOWEST
      # credential layer, under the managed .credentials.yaml the web Models
      # page writes and under a per-run `DEEPSEEK_API_KEY=… dsh`, so placing the
      # key here configures the official route without taking it away from
      # either override. A shell export would instead occupy the top,
      # inherited-environment layer, which dsh reports as read-only and refuses
      # to let the UI replace — and it would only ever reach interactive shells.
      envFile = "${config.home.homeDirectory}/.dsh/.env";

      # BOOTSTRAP ONLY. What the endpoint serves is the endpoint's fact, not
      # this module's: `vllm` is a hand-declared pi-ai route, so unlike the
      # official route — a catalog route that picks up new models on its own —
      # its models have to be spelled somewhere, and anything spelled here is a
      # COPY that drifts. It already did: this list named one model at a
      # 1048576 window long after the deployment had moved to two at 600000,
      # which is the dangerous half, since an over-declared window sizes
      # compaction against a ceiling the server enforces and fails only deep
      # into a long session.
      #
      # So the catalog is discovered at activation (see vllmCatalogSync below)
      # and this list is only what a first activation writes when the endpoint
      # cannot be reached. It is seeded, never forced — a failed discovery must
      # leave the last GOOD catalog in place, not overwrite it with this copy.
      seedModels = [
        "deepseek-v4-flash-0731"
        "DeepSeek-v4.1-Flash-EXL3"
      ];

      # The route seeded as the default for a new session.
      model = "deepseek-v4-flash-0731";

      # Route-level backstop, consulted only for a model carrying no window of
      # its own — which, after any successful discovery, is none of them. Keep
      # it at or below the smallest window the deployment serves: too low only
      # wastes context, too high silently overruns the server.
      contextWindow = 600000;

      # pi-ai's OpenAI-compatible transport will not build a request without
      # either a credential or an Authorization header, but this endpoint is
      # keyless — Cloudflare Access in front of it does the authenticating.
      # Upstream sanctions exactly this: "a keyless local server needs a
      # placeholder credential referenced by apiKeyEnv or an Authorization
      # entry in headers". Not a secret, so it is inlined rather than sops'd,
      # and it is safe from the headers-are-never-redacted caveat below.
      placeholderKey = "unused-cloudflare-access-fronts-this";

      route = config.deepseek.defaultRoute;

      # Replaces the vllm route's model catalog with what the endpoint reports,
      # so the one fact this module cannot own is read from its owner instead of
      # copied. Each model carries its own max_model_len, which means the window
      # can no longer be wrong even if the deployment serves models that differ.
      #
      # Non-destructive by construction: every failure path — unreachable
      # endpoint, HTTP error, unparseable body, empty list, an entry missing an
      # id or a positive window — warns and exits 0, leaving whatever catalog is
      # already in settings.yaml. That matters more than freshness: this route
      # goes down, and an activation during the outage must not be the thing
      # that erases the catalog describing it.
      vllmCatalogSync = pkgs.writeShellScript "dsh-sync-vllm-catalog" ''
        set -eu
        settings="$1"
        id_file="$2"
        secret_file="$3"
        url_file="$4"

        yq=${lib.getExe pkgs.yq-go}

        keep() {
          echo "deepseek: $1; keeping the vllm catalog already in $settings" >&2
          exit 0
        }

        if ! body="$(${lib.getExe pkgs.curl} -sS --fail --max-time 8 \
          -H "CF-Access-Client-Id: $(cat "$id_file")" \
          -H "CF-Access-Client-Secret: $(cat "$secret_file")" \
          -H "Authorization: Bearer ${placeholderKey}" \
          "$(cat "$url_file")/models" 2>/dev/null)"; then
          keep "vllm endpoint unreachable"
        fi

        if ! catalog="$(printf '%s' "$body" | "$yq" -p=json -o=json \
          '[.data[] | {"id": .id, "contextWindow": .max_model_len}]' 2>/dev/null)"; then
          keep "vllm /models returned a body this cannot read"
        fi

        total="$(printf '%s' "$catalog" | "$yq" -p=json 'length')"
        usable="$(printf '%s' "$catalog" | "$yq" -p=json \
          '[.[] | select((.id // "" | length) > 0 and (.contextWindow // 0) > 0)] | length')"

        [ "$total" -gt 0 ] || keep "vllm /models listed no models"
        [ "$total" = "$usable" ] || keep "vllm /models listed an entry with no id or no positive max_model_len"

        DSH_VLLM_CATALOG="$catalog" "$yq" -i \
          '.["llm-pi-ai"].providers.vllm.models = (strenv(DSH_VLLM_CATALOG) | from_json)' \
          "$settings"

        echo "deepseek: vllm catalog synced —" \
          "$(printf '%s' "$catalog" | "$yq" -p=json -o=tsv '[.[] | .id + " (" + (.contextWindow | tostring) + ")"] | join(", ")')" >&2
      '';

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
      #
      # agent-default-model is the one key SEEDED rather than forced: the
      # composer's /model picker records its choice there, and forcing it would
      # revert that on the next activation — exactly when the endpoint is down
      # and the switch matters. Assigned as a whole section, never field by
      # field, because the harness treats provider+model as one atomic route and
      # ignores a half-pinned one rather than merging it with a default.
      program = ''
        .["llm-pi-ai"].providers.vllm.api = "openai-completions" |
        .["llm-pi-ai"].providers.vllm.displayName = "vLLM (self-hosted)" |
        .["llm-pi-ai"].providers.vllm.baseURL = strenv(DSH_VLLM_URL) |
        del(.["llm-pi-ai"].providers.vllm.apiKeyEnv) |
        .["llm-pi-ai"].providers.vllm.defaultContextWindow = ${toString contextWindow} |
        .["llm-pi-ai"].providers.vllm.headers.Authorization = "Bearer ${placeholderKey}" |
        .["llm-pi-ai"].providers.vllm.headers["CF-Access-Client-Id"] = strenv(DSH_CF_ID) |
        .["llm-pi-ai"].providers.vllm.headers["CF-Access-Client-Secret"] = strenv(DSH_CF_SECRET) |
        .["llm-pi-ai"].providers.vllm.models = (.["llm-pi-ai"].providers.vllm.models // ${
          builtins.toJSON (map (id: { inherit id; }) seedModels)
        }) |
        .["agent-default-model"] = (.["agent-default-model"] // {"provider": "${route.provider}", "model": "${route.model}"})
      '';

      # Everything in this module that consumes a sops secret, in one place.
      #
      # It does NOT live in home.activation, and that is the whole point: the
      # secrets are installed by sops-nix.service, which home-manager starts
      # from `reloadSystemd` — the LAST activation entry. Every earlier entry
      # therefore runs before the secrets it wants exist, so a newly added
      # secret is guaranteed to be missing on the very activation that
      # introduces it. `entryAfter [ "sops-nix" ]` does not help: that DAG entry
      # is not what installs them. Ordering the work after the unit is the only
      # spelling that is actually true, and it costs nothing — a boot runs it
      # too, so the discovered catalog refreshes without waiting for a rebuild.
      harnessSync = pkgs.writeShellScript "dsh-harness-sync" ''
        set -eu
        umask 077

        yq=${lib.getExe pkgs.yq-go}

        # settings.yaml carries the Cloudflare Access client secret in cleartext:
        # dsh types `headers` as a plain string dict, and only `apiKeyEnv` gets
        # credential indirection, so home.file would publish it to the
        # world-readable Nix store. Written here instead, mode 0600, with the
        # values passed through the environment (strenv) so they never appear in
        # argv where /proc/*/cmdline would expose them.
        #
        # Upstream caveat worth knowing: a credential in `headers` is returned
        # verbatim by a redacted describe() and rendered by the Models page. That
        # is a known limitation in llm-pi-ai, not something this config can avoid.
        dsh_id="${secretsDir}/cf-access-client-id"
        dsh_secret="${secretsDir}/cf-access-client-secret"
        dsh_url="${secretsDir}/vllm-base-url"

        if [ -f "$dsh_id" ] && [ -f "$dsh_secret" ] && [ -f "$dsh_url" ]; then
          mkdir -p "$(dirname "${settingsFile}")"
          [ -f "${settingsFile}" ] || : > "${settingsFile}"
          chmod 600 "${settingsFile}"

          if DSH_CF_ID="$(cat "$dsh_id")" \
             DSH_CF_SECRET="$(cat "$dsh_secret")" \
             DSH_VLLM_URL="$(cat "$dsh_url")" \
             "$yq" -i '${program}' "${settingsFile}"; then
            # A separate process on purpose: it reports every failure by exiting
            # 0, which as an inlined function would abort this script and skip
            # the .env write below.
            ${vllmCatalogSync} "${settingsFile}" "$dsh_id" "$dsh_secret" "$dsh_url"
          else
            echo "deepseek: yq merge failed for ${settingsFile} (left unchanged)" >&2
          fi
        else
          echo "deepseek: sops secrets not present yet, skipping ${settingsFile}" >&2
        fi

        # The official api.deepseek.com route needs no settings section at all —
        # dsh-base already mounts llm-deepseek, which owns the
        # `deepseek-official` route and defaults its endpoint, its catalog and
        # its DEEPSEEK_API_KEY credential reference. Supplying the key is the
        # whole of the configuration, and it is what makes that route a working
        # fallback when the vLLM endpoint is unreachable: /model in either front
        # end switches to it without a rebuild.
        #
        # umask above makes the temp file 0600 and the rename preserves it, so
        # no reader ever sees the key mode-0644 or half-written.
        dsh_key="${secretsDir}/deepseek-api-key"

        if [ -f "$dsh_key" ]; then
          mkdir -p "$(dirname "${envFile}")"
          printf 'DEEPSEEK_API_KEY=%s\n' "$(cat "$dsh_key")" > "${envFile}.tmp"
          mv -f "${envFile}.tmp" "${envFile}"
        else
          echo "deepseek: deepseek-api-key not present yet, skipping ${envFile}" >&2
        fi
      '';

      profiles = config.deepseek.profiles;

      jsonFormat = pkgs.formats.json { };
      yamlFormat = pkgs.formats.yaml { };

      # A dsh profile is a directory of four files, three of which are static
      # and are therefore owned here. Upstream's initProfile() writes each of
      # them only when it is absent and documents that "existing files are never
      # touched", so pre-placing them makes the harness's own scaffolding a
      # no-op rather than a competitor.
      #
      # Two things in that directory are deliberately NOT managed:
      #
      #   cordis.yml     the Cordis loader rewrites it on every boot (its
      #                  content is an invariant empty entry list, but the write
      #                  still happens), so it cannot be a read-only store
      #                  symlink. Upstream's own header says to edit
      #                  cordis.patch.yml instead, which is what `patch` below
      #                  generates.
      #
      #   node_modules/  healProfilesModuleFallback() maintains
      #                  profiles/node_modules as one symlink per package in the
      #                  installation's dependency closure, re-pointing them
      #                  when the store path moves — so a dsh version bump
      #                  relinks itself. It throws outright if it finds a real
      #                  directory there, so Nix must stay out of it.
      #
      # Because every bundle resolves from the installation first, a profile
      # named here needs no `dsh plugin add` and no pnpm: declaring it is enough
      # for `dsh --profile <name>` to boot.
      profilePath = name: ".dsh/profiles/${name}";

      pnpmWorkspace = pkgs.writeText "dsh-pnpm-workspace.yaml" ''
        packages:
          - .

        nodeLinker: hoisted
        autoInstallPeers: false
      '';

      # Skins built by the dsh-skin overlay, one derivation per theme directory.
      availableSkins = pkgs.dshSkins or { };

      skinFor = profile: if profile.skin == null then null else availableSkins.${profile.skin} or null;

      # A skin is just another bundle layer. Appending it last puts its patch
      # layer above the product's own, which is what lets it insert its client
      # entry. Nothing is disabled: an unselected theme is simply never linked
      # into the profile, so "exactly one skin" is structural rather than an
      # assertion we have to police.
      # Bundle layers, broadest first: the shipped bundles, then any packaged
      # third-party plugin, then the skin. The skin stays last so its patch
      # layer sits above the product's own — that ordering is what lets it
      # insert its client entry.
      bundlesFor =
        profile:
        profile.bundles
        ++ map (plugin: plugin.packageName) profile.plugins
        ++ lib.optional (skinFor profile != null) (skinFor profile).packageName;

      # dsh mounts no MCP client of its own — dsh-mcp-client ships in the
      # installation's closure but no bundle inserts it — so every declared
      # server becomes one row here, in every profile. The rows go in their own
      # patch entry ahead of the profile's, which leaves a profile free to
      # retarget or disable `mcp-<name>` by id in its own layer.
      mcpRows = lib.mapAttrsToList (server: cfg: {
        id = "mcp-${server}";
        name = "@deepseek-ai/dsh-mcp-client";
        config = {
          serverName = server;
          transport = "stdio";
          inherit (cfg) command args;
        };
      }) config.deepseek.mcpServers;

      patchFor = profile: lib.optional (mcpRows != [ ]) { insert = mcpRows; } ++ profile.patch;

      manifestFor =
        name: profile:
        jsonFormat.generate "dsh-profile-${name}-package.json" {
          name = "dsh-profile-${name}";
          private = true;
          dependencies = { };
          dsh.profile.bundles = bundlesFor profile;
        };

      # force, because the harness seeds these as real files on first boot and
      # the web UI can rewrite package.json through `dsh plugin`. Declaring a
      # profile means Nix is the source of truth for its shape; drift is
      # replaced at activation rather than silently accumulating.
      filesFor =
        name: profile:
        {
          "${profilePath name}/package.json" = {
            source = manifestFor name profile;
            force = true;
          };
          "${profilePath name}/cordis.patch.yml" = {
            source = yamlFormat.generate "dsh-profile-${name}-cordis.patch.yml" (patchFor profile);
            force = true;
          };
          "${profilePath name}/pnpm-workspace.yaml" = {
            source = pnpmWorkspace;
            force = true;
          };
        }
        # The skin lands in the profile's OWN node_modules, which node's
        # resolution walk reaches before profiles/node_modules. That keeps Nix
        # strictly out of the directory healProfilesModuleFallback manages —
        # it throws on anything there that is not a symlink it created — and
        # it means two profiles can wear different skins without their
        # home.file keys colliding.
        // lib.optionalAttrs (skinFor profile != null) {
          "${profilePath name}/node_modules/${(skinFor profile).packageName}".source = skinFor profile;
        }
        # Packaged plugins land in the same per-profile node_modules for the
        # same reason, and their own @deepseek-ai peers still resolve from
        # profiles/node_modules further up the walk — so a plugin never carries
        # a second copy of the harness it plugs into.
        // lib.listToAttrs (
          map (plugin: {
            name = "${profilePath name}/node_modules/${plugin.packageName}";
            value.source = plugin.packageRoot;
          }) profile.plugins
        );

      # normalizeShippedProfile() runs on every profile load and rewrites
      # package.json in place when the bundle list is exactly one of these
      # superseded tuples. That write would land on a read-only store symlink,
      # so the assertion below refuses the configuration instead of letting it
      # fail at runtime with an EROFS from inside node.
      supersededTuples = {
        headless = [
          "@deepseek-ai/dsh-base"
          "@deepseek-ai/dsh-web-app"
          "@deepseek-ai/dsh-headless"
        ];
      };

      superseded = lib.filterAttrs (
        name: profile: (supersededTuples.${name} or null) == profile.bundles
      ) profiles;
    in
    {
      options.deepseek.defaultRoute = lib.mkOption {
        type = lib.types.submodule {
          options = {
            provider = lib.mkOption {
              type = lib.types.str;
              description = "Provider route id, as an adapter registers it.";
            };

            model = lib.mkOption {
              type = lib.types.str;
              description = "Model id within that provider's catalog.";
            };
          };
        };
        default = {
          provider = "vllm";
          inherit model;
        };
        example = {
          provider = "deepseek-official";
          model = "deepseek-v4-flash";
        };
        description = ''
          Route a new session starts on, seeded into `agent-default-model` the
          first time settings.yaml has no such section. It is a seed, not a
          pin: the composer's `/model` picker writes that section, and this
          module leaves an existing one alone so a runtime switch survives
          activation.

          One submodule rather than two options because the harness resolves a
          route atomically — a provider without its model is discarded rather
          than merged with a default, so the pair cannot be allowed to drift
          apart.

          The dsh-tui front end keeps its own choice in
          `~/.dsh-tui/model.json` and does not read this section at all.
        '';
      };

      options.deepseek.profiles = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              bundles = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = ''
                  Ordered `dsh.profile.bundles` layer list. Each entry is a
                  plugin-bundle package name resolved from the dsh installation,
                  so only bundles that ship in the box are usable without pnpm.
                '';
              };

              skin = lib.mkOption {
                type = lib.types.nullOr (lib.types.enum (lib.attrNames availableSkins));
                default = null;
                example = "placeholder";
                description = ''
                  Web skin this profile wears, named after a directory under
                  `modules/workstation/overlays/dsh-skin/_themes`. The skin is
                  linked into the profile and appended to its bundle list;
                  switching themes is changing this one value. Only meaningful
                  for profiles that load a web UI.
                '';
              };

              plugins = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                example = lib.literalExpression "[ pkgs.dsh-tui ]";
                description = ''
                  Third-party bundle layers packaged as derivations, appended to
                  the bundle list in order. Each needs `passthru.packageName`
                  and `passthru.packageRoot`; the root is linked into this
                  profile's own `node_modules` under that name, which is how a
                  bundle outside the dsh installation's closure becomes
                  resolvable without `dsh plugin add` or pnpm.
                '';
              };

              patch = lib.mkOption {
                type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
                default = [ ];
                description = ''
                  The profile's `cordis.patch.yml` user layer, applied after
                  every bundle layer: id-targeted config overrides, disables and
                  insert lists. Upstream also allows `!!js` expressions in this
                  file; those are not expressible as Nix values and so are not
                  supported here.
                '';
              };
            };
          }
        );
        default = { };
        description = ''
          dsh profiles to materialize under ~/.dsh/profiles. A profile is an
          ordered stack of plugin-bundle patch layers under its own override
          layer, booted with `dsh --profile <name>`.
        '';
      };

      options.deepseek.mcpServers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              command = lib.mkOption {
                type = lib.types.str;
                description = ''
                  Executable dsh spawns for this server's stdio transport. It
                  starts from a scrubbed parent environment — every name
                  matching `/KEY|PASSWORD|SECRET|TOKEN/i` and every `DSH_*` name
                  is stripped — so a server needing a credential has to read it
                  itself rather than inherit it.
                '';
              };

              args = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Arguments passed to `command`.";
              };
            };
          }
        );
        default = { };
        description = ''
          MCP servers mounted into every dsh profile, keyed by the name that
          namespaces their model-facing tools (`mcp__<name>__<tool>`). dsh
          validates that name as `[A-Za-z0-9_-]{1,32}`. Only the stdio
          transport is modeled; nothing here needs the HTTP one yet.
        '';
      };

      config = {
        assertions = lib.mapAttrsToList (name: _: {
          assertion = false;
          message = ''
            deepseek.profiles.${name}.bundles is the superseded tuple that dsh
            normalizes by rewriting package.json in place, which cannot work
            against a Nix-managed store symlink. Drop
            "@deepseek-ai/dsh-web-app" from the list.
          '';
        }) superseded;

        # Global dsh directives. The loader's user-global scope is the fixed
        # path $DSH_HOME/AGENTS.md — dshHome is configurable, the file name is
        # not — and it is read before any project AGENTS.md, so this is the
        # broadest layer every session starts from. Edit ./AGENTS.md next to
        # this module, not the symlink.
        home.file = {
          ".dsh/AGENTS.md".source = ./AGENTS.md;
        }
        // lib.concatMapAttrs filesFor profiles;

        # The two profiles the harness ships templates for. mkDefault so another
        # module can retune a bundle list without mkForce, and separate
        # definitions so declaring a third profile elsewhere merges rather than
        # replacing these.
        deepseek.profiles = {
          web.skin = lib.mkDefault "neko";
          web.bundles = lib.mkDefault [
            "@deepseek-ai/dsh-base"
            "@deepseek-ai/dsh-web-app"
          ];
          headless.bundles = lib.mkDefault [
            "@deepseek-ai/dsh-base"
            "@deepseek-ai/dsh-headless"
          ];

          # The terminal front end, over dsh-base alone: dsh-tui replaces the
          # web app rather than layering on it, and its patch owns the
          # interactive surface. No skin — that is a web-client concern.
          tui.bundles = lib.mkDefault [ "@deepseek-ai/dsh-base" ];
          tui.plugins = lib.mkDefault [
            pkgs.dsh-tui
            pkgs.dsh-herdr
          ];

          # dsh-herdr reports this pane's state, session ref and metadata to
          # herdr from the harness's own events. Its defaults report as agent
          # `dsh` from source `herdr:dsh-agent-state`; both are retargeted here
          # onto the pair the herdr overlay's patch whitelists in
          # `is_official_agent_source`, which is what lets herdr accept the
          # session reference and bring the conversation back after a server
          # restart. The pair is deliberately absent from
          # `is_reserved_native_state_source`, so these reports also carry
          # lifecycle authority instead of only setting the session ref —
          # event-driven state beats reading the footer.
          #
          # An id-targeted row replaces that row's whole config; every field
          # left out falls back to the bundle's own schema default.
          tui.patch = lib.mkDefault [
            {
              id = "herdr-agent-state";
              config = {
                agent = "deepseek";
                source = "herdr:deepseek";
              };
            }
          ];
        };

        # Ordered after sops-nix.service because that unit is what installs
        # the secrets, and home-manager starts it from `reloadSystemd` — after
        # every home.activation entry. Work that needs a secret therefore
        # cannot live in activation at all: a newly added secret is missing on
        # the activation that introduces it, and no DAG dependency fixes that,
        # because the entry named "sops-nix" is not the thing doing the work.
        #
        # WantedBy default.target so a login runs it too: the vllm catalog it
        # discovers then refreshes on boot rather than only on rebuild.
        systemd.user.services.dsh-harness-sync = {
          Unit = {
            Description = "Render dsh settings.yaml and credentials from sops secrets";
            Wants = [ "sops-nix.service" ];
            After = [ "sops-nix.service" ];
          };

          Service = {
            Type = "oneshot";
            ExecStart = toString harnessSync;
          };

          Install.WantedBy = [ "default.target" ];
        };
      };
    };
}
