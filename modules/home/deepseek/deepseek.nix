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

      # The home-level patch layer: composed after every bundle layer and after
      # each profile's own cordis.patch.yml, so it reaches every profile. It is
      # where the vllm routes live because it is the one patch file Nix does
      # NOT own — their models are discovered at runtime and an outage must
      # leave the last good ones in place, so the render has to read the file
      # back and rewrite it, which a store symlink cannot be; and the remote
      # route carries a secret that only exists once sops has run. dsh 0.2.0
      # dropped settings.yaml, which used to hold the vllm route; its one-shot
      # import could only write the read-only profile patch, so the route was
      # silently lost.
      homePatchFile = "${config.home.homeDirectory}/.dsh/cordis.patch.yml";

      # The harness home's own environment layer. dsh reads it as the LOWEST
      # credential layer, under the managed .credentials.yaml the web Models
      # page writes and under a per-run `DEEPSEEK_API_KEY=… dsh`, so placing the
      # key here configures the official route without taking it away from
      # either override. A shell export would instead occupy the top,
      # inherited-environment layer, which dsh reports as read-only and refuses
      # to let the UI replace — and it would only ever reach interactive shells.
      envFile = "${config.home.homeDirectory}/.dsh/.env";

      # The vLLM routes, declared once in ../vllm-routes.nix and shared with
      # Prime Agent. What an endpoint serves is the endpoint's fact, not this
      # module's: these are hand-declared pi-ai routes, so unlike the official
      # route — a catalog route that picks up new models on its own — their
      # models have to be spelled somewhere, and anything spelled here is a
      # COPY that drifts. So each catalog is discovered by dsh-harness-sync
      # (see below), and a route's seedModels are only what a first render
      # writes when its endpoint cannot be reached.
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

      seedFor = r: builtins.toJSON (map (id: { inherit id; }) r.seedModels);

      # pi-ai's OpenAI-compatible transport will not build a request without
      # either a credential or an Authorization header, and no endpoint checks
      # one: Cloudflare Access does the authenticating in front of each.
      # Upstream sanctions exactly this: "a keyless local server needs a
      # placeholder credential referenced by apiKeyEnv or an Authorization
      # entry in headers". Not a secret, so it is inlined rather than sops'd.
      inherit (pkgs.vllm-catalog) placeholderKey;

      # A shell variable's expansion, double-quoted.
      shellRef = name: "\"\$${name}\"";

      route = config.deepseek.defaultRoute;

      # Every vLLM route as one id-targeted row of the home patch, which
      # replaces the llm-pi-ai entry's whole config — the bundle gives it
      # none, so nothing is lost by restating. Every other row in the file is
      # the user's and is carried through, so the render is safe to re-run.
      #
      # A route is rendered only when its secret files are all present (its
      # URL variable is set); until then whatever the file already holds for
      # it is carried through as it is. Its models are replaced only by a
      # catalog pkgs.vllm-catalog fetched and validated — the endpoint's own
      # answer, with each model's max_model_len, so no window here can be
      # wrong. When the fetch fails the route's existing models stay, and only
      # a route that has none yet gets its seed list: these endpoints go down,
      # and a render during an outage must not be the thing that erases the
      # catalog describing it. Each route keeps its own, so one endpoint being
      # down never touches another's.
      #
      # Each model gets the route's reasoningEfforts as dsh's level → wire
      # map. pi-ai's openai-completions dispatch sends the wire value as
      # `reasoning_effort`, which the endpoints honor, and dsh offers only the
      # declared levels: vLLM validates the field against the chat template,
      # so an undeclared one would be a 400. `off` is `none`. Reasoning output
      # surfaces either way — pi-ai's response parser scans
      # reasoning_content/reasoning/reasoning_text.
      reasoningEfforts =
        efforts:
        lib.optionalAttrs (lib.elem "none" efforts) { off = "none"; }
        // lib.genAttrs (lib.remove "none" efforts) lib.id;

      routeProgram =
        id: r:
        let
          key = builtins.toJSON id;
          env = "DSH_${r.envName}";
          withEfforts =
            lib.optionalString (r.reasoningEfforts != [ ])
              " | map(. + ${builtins.toJSON { reasoningEfforts = reasoningEfforts r.reasoningEfforts; }})";
        in
        ''
          (({${key}: {
            "api": "openai-completions",
            "displayName": ${builtins.toJSON r.displayName},
            "baseURL": strenv(${env}_URL),
            "defaultContextWindow": ${toString r.contextWindow},
            "headers": {
              "Authorization": "Bearer ${placeholderKey}"${lib.optionalString (behindAccess r) ''
                ,
                              "CF-Access-Client-Id": strenv(${env}_ACCESS_ID),
                              "CF-Access-Client-Secret": strenv(${env}_ACCESS_SECRET)''}
            },
            "models": (((strenv(${env}_CATALOG) | select(. != "") | from_json) // $prev[${key}].models // ${seedFor r})${withEfforts})
          }} | select(strenv(${env}_URL) != "")) //
          ($prev | with_entries(select(.key == ${key}))))
        '';

      program = ''
        ([.[] | select(.id == "llm-pi-ai") | .config.providers][0] // {}) as $prev |
        [.[] | select(.id != "llm-pi-ai")] + [{
          "id": "llm-pi-ai",
          "config": {"providers": ({} + ${lib.concatStringsSep " + " (lib.mapAttrsToList routeProgram routes)})}
        }]
      '';

      # Discovers one route's catalog and reads its URL and Access credentials
      # into route_<id>_* shell variables, kept apart from the script's own
      # names (a route named vllm would clobber $vllm_catalog), for the render
      # below.
      #
      # The Access client secret lands in the home patch in cleartext: dsh
      # types `headers` as a plain string dict, and only `apiKeyEnv` gets
      # credential indirection, so home.file would publish it to the
      # world-readable Nix store. Written by the sync instead, mode 0600 via
      # the umask and an atomic rename, with the values passed through the
      # environment (strenv) so they never appear in argv where
      # /proc/*/cmdline would expose them.
      #
      # Upstream caveat worth knowing: a credential in `headers` is returned
      # verbatim by a redacted describe() and rendered by the Models page.
      # That is a known limitation in llm-pi-ai, not something this config
      # can avoid.
      fetchRoute =
        id: r:
        let
          v = "route_${lib.toLower r.envName}";
          files = routeFiles r;
        in
        ''
          ${v}_url="" ${v}_access_id="" ${v}_access_secret="" ${v}_catalog=""

          if ${lib.concatMapStringsSep " && " (f: "[ -f ${lib.escapeShellArg f} ]") files}; then
            if ${v}_catalog="$("$vllm_catalog" ${lib.escapeShellArgs (files ++ [ (toString r.contextWindow) ])})"; then
              echo "deepseek: ${id} catalog fetched — $(describe ${shellRef "${v}_catalog"})" >&2
            else
              echo "deepseek: keeping the ${id} catalog already in ${homePatchFile}" >&2
              ${v}_catalog=""
            fi
            ${v}_url="$(cat ${lib.escapeShellArg r.baseUrlFile})"
            ${lib.optionalString (behindAccess r) ''
              ${v}_access_id="$(cat ${lib.escapeShellArg r.accessClientIdFile})"
              ${v}_access_secret="$(cat ${lib.escapeShellArg r.accessClientSecretFile})"
            ''}
          else
            echo "deepseek: ${id} secrets not present yet, keeping that route as it is in ${homePatchFile}" >&2
          fi
        '';

      routeEnv =
        _id: r:
        let
          v = "route_${lib.toLower r.envName}";
          env = "DSH_${r.envName}";
        in
        ''
          ${env}_URL=${shellRef "${v}_url"} \
          ${env}_ACCESS_ID=${shellRef "${v}_access_id"} \
          ${env}_ACCESS_SECRET=${shellRef "${v}_access_secret"} \
          ${env}_CATALOG=${shellRef "${v}_catalog"} \
        '';

      # Everything in this module that consumes a sops secret or the network,
      # in one place.
      #
      # It does NOT live in home.activation, and that is the whole point: the
      # secrets are installed by sops-nix.service, which home-manager starts
      # from `reloadSystemd` — the LAST activation entry. Every earlier entry
      # therefore runs before the secrets it wants exist, so a newly added
      # secret is guaranteed to be missing on the very activation that
      # introduces it. `entryAfter [ "sops-nix" ]` does not help: that DAG entry
      # is not what installs them. Ordering the work after the unit is the only
      # spelling that is actually true, and it costs nothing — a boot runs it
      # too, so the discovered catalogs refresh without waiting for a rebuild,
      # and no activation ever stalls on an endpoint that is down.
      harnessSync = pkgs.writeShellScript "dsh-harness-sync" ''
        set -eu
        umask 077

        yq=${lib.getExe pkgs.yq-go}
        vllm_catalog=${lib.getExe pkgs.vllm-catalog}

        describe() {
          printf '%s' "$1" | "$yq" -p=json -o=tsv '[.[] | .id + " (" + (.contextWindow | tostring) + ")"] | join(", ")'
        }

        ${lib.concatStrings (lib.mapAttrsToList fetchRoute routes)}
        mkdir -p "$(dirname "${homePatchFile}")"
        # An empty patch file fails boot, so the render always starts from a
        # list — an absent file is the empty one.
        if [ -s "${homePatchFile}" ]; then base="$(cat "${homePatchFile}")"; else base="[]"; fi

        # Swapped in by an atomic rename, so dsh never boots from a half-written
        # patch.
        if printf '%s\n' "$base" |
          ${lib.concatStrings (lib.mapAttrsToList routeEnv routes)}  "$yq" '${program}' > "${homePatchFile}.tmp"; then
          mv -f "${homePatchFile}.tmp" "${homePatchFile}"
        else
          rm -f "${homePatchFile}.tmp"
          echo "deepseek: yq merge failed for ${homePatchFile} (left unchanged)" >&2
        fi

        # The official api.deepseek.com route needs no patch row at all —
        # dsh-base already mounts llm-deepseek, which owns the
        # `deepseek-official` route and defaults its endpoint, its catalog and
        # its DEEPSEEK_API_KEY credential reference. Supplying the key is the
        # whole of the configuration. It is the route a new session starts on
        # (see deepseek.defaultRoute), and /model in either front end switches
        # between it and the vLLM routes without a rebuild.
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

      # dsh-herdr reports a pane's state, session ref and metadata to herdr from
      # the harness's own events. The bundle defaults to reporting as agent `dsh`
      # from source `herdr:dsh-agent-state`; both are retargeted onto the pair the
      # herdr overlay's patch whitelists in `is_official_agent_source`, which is
      # what lets herdr accept the session reference and bring the conversation
      # back after a server restart. That pair is deliberately absent from
      # `is_reserved_native_state_source`, so these reports also carry lifecycle
      # authority rather than only setting the session ref — state from the
      # harness's own events beats reading the footer.
      #
      # Every profile carries it: the bundle is a strict no-op outside a herdr
      # pane (HERDR_ENV=1 plus a socket and pane id), so the web profile's copy
      # simply never activates. An id-targeted row replaces that row's whole
      # config; every field left out falls back to the bundle's schema default.
      herdrStateRow = {
        id = "herdr-agent-state";
        config = {
          agent = "deepseek";
          source = "herdr:deepseek";
        };
      };

      # dsh-mascot reports session state to the ESP32 desk mascot from dsh's own
      # agent, approval and question events. It carries no patch row: the
      # bundle's own cordis.patch.yml already inserts it with the device's
      # address, and a second copy here would be a second place to edit when
      # that address changes. The address does also appear in
      # home/claude/mascot.nix, which reaches Claude Code and Codex through
      # their hook seams.
      #
      # Every profile carries it. The plugin is inert when the device does not
      # answer, so a profile that never sees it simply posts into a 400 ms
      # timeout and moves on.

      jsonFormat = pkgs.formats.json { };

      # A dsh profile is a directory of four files. package.json and
      # pnpm-workspace.yaml are static and owned here outright. Upstream's
      # initProfile() writes each only when it is absent and documents that
      # "existing files are never touched", so pre-placing them makes the
      # harness's own scaffolding a no-op rather than a competitor.
      #
      # cordis.patch.yml is shared: dsh 0.2.0 persists settings-page and
      # /model edits into it, so it is a real file rendered at activation (see
      # profilePatchRender) rather than a store symlink an edit would replace
      # and the next activation would silently revert.
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

      # The default route is fixed at build time, so unlike the vllm routes it
      # is built here, in the profile layer. Not in the home patch: that layer
      # outranks the profile's, so a default placed there would override
      # anything the profile layer sets. It goes first so a profile's own rows
      # can still retarget it.
      defaultRouteRow = {
        id = "agent-default-model";
        config = { inherit (route) provider model; };
      };

      # dsh-tui reads none of the profile rows: its route is the `/model`
      # choice it keeps in ~/.dsh-tui/model.json, in exactly this shape
      # (modelPrefs.js). Seeded like defaultRouteRow — written only when the
      # file is missing, so a choice made in dsh-tui outlives a rebuild. An
      # unreadable file is left alone too: dsh-tui already treats it as unset,
      # and replacing it would be a pin by another name.
      dshTuiModelSeed = jsonFormat.generate "dsh-tui-model.json" { inherit (route) provider model; };
      usesDshTui = lib.any (profile: lib.elem pkgs.dsh-tui profile.plugins) (lib.attrValues profiles);

      # The rows Nix owns outright in a profile's patch, replaced on every
      # activation. defaultRouteRow is not among them: it is only seeded.
      ownedRowsFor = profile: lib.optional (mcpRows != [ ]) { insert = mcpRows; } ++ profile.patch;

      # Merges the Nix rows into a profile's cordis.patch.yml without taking
      # the file away from dsh, which writes in-app edits into it:
      #
      #   - rows whose id a profile declares in `patch`, and the MCP insert
      #     row (recognised by its mcp-* ids), are replaced every time;
      #   - agent-default-model is written only when no such row exists, so a
      #     /model choice outlives a rebuild — a seed, not a pin. One that
      #     names a vLLM route's former id is moved onto its current id;
      #   - every other row is dsh's or the user's and is carried through.
      #
      # yq-go rather than a JSON round trip because the file holds what dsh's
      # config editor writes back, `!!js` expressions and comments included.
      # A store symlink left by the old home.file entry counts as no content.
      # Written by atomic rename, and never empty: an empty patch fails boot.
      profilePatchRender = pkgs.writeShellScript "dsh-profile-patch-render" ''
        set -eu
        file="$1"
        if [ -f "$file" ] && [ ! -L "$file" ]; then base="$(cat "$file")"; else base="[]"; fi
        [ -n "$base" ] || base="[]"
        mkdir -p "$(dirname "$file")"
        if printf '%s\n' "$base" | ${lib.getExe pkgs.yq-go} '
          (strenv(DSH_RENAMES) | from_json) as $ren |
          ((. // []) | with(.[] | select(.id == "agent-default-model" and (.config.provider as $p | $ren | has($p)));
            .config.provider = $ren[.config.provider] | .config.provider style="")) as $cur |
          (strenv(DSH_OWNED_IDS) | from_json) as $owned |
          ([$cur[] | select(.id == "agent-default-model")] | length) as $seeded |
          (([strenv(DSH_DEFAULT_ROW) | from_json | select($seeded == 0)]
            + (strenv(DSH_NIX_ROWS) | from_json)) | ... style="")
          + [$cur[]
              | select((.id as $i | $owned | any_c(. == $i)) | not)
              | select((has("insert") and (.insert | all_c((.id // "") | test("^mcp-")))) | not)]
        ' > "$file.tmp"; then
          mv -f "$file.tmp" "$file"
        else
          # A patch the merge cannot read is left exactly as it is: failing
          # activation over it would block every unrelated home change.
          rm -f "$file.tmp"
          echo "deepseek: could not merge $file (left unchanged)" >&2
        fi
      '';

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
          provider = "deepseek-official";
          model = "deepseek-v4-pro";
        };
        example = {
          provider = "qwen-lan";
          model = "Qwen3.8-27B-FP8";
        };
        description = ''
          Route a new session starts on, seeded as the `agent-default-model`
          row of every profile's `cordis.patch.yml` when the file has none. It
          is a seed, not a pin: the web composer's `/model` picker writes that
          row, and activation leaves an existing one alone so the choice
          survives a rebuild.

          One submodule rather than two options because the harness resolves a
          route atomically — a provider without its model is discarded rather
          than merged with a default, so the pair cannot be allowed to drift
          apart.

          The dsh-tui front end ignores that row and keeps its own choice
          in `~/.dsh-tui/model.json`, which its `/model` picker rewrites.
          That file is seeded from this route the same way: written only
          when it does not exist.
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
                  Rows Nix owns in the profile's `cordis.patch.yml`, applied
                  after every bundle layer. Each row must carry an `id`: that is
                  how activation finds and replaces its own rows while keeping
                  the ones dsh writes into the same file. Upstream also allows
                  `!!js` expressions in this file; those are not expressible as
                  Nix values and so are not supported here.
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
        assertions =
          lib.mapAttrsToList (name: _: {
            assertion = false;
            message = ''
              deepseek.profiles.${name}.bundles is the superseded tuple that dsh
              normalizes by rewriting package.json in place, which cannot work
              against a Nix-managed store symlink. Drop
              "@deepseek-ai/dsh-web-app" from the list.
            '';
          }) superseded
          ++ lib.mapAttrsToList (name: profile: {
            assertion = lib.all (row: row ? id) profile.patch;
            message = ''
              Every row in deepseek.profiles.${name}.patch needs an `id`.
              Activation shares cordis.patch.yml with dsh's own config editor
              and finds the rows it owns by id; a row without one could never
              be replaced, so it would pile up on every rebuild.
            '';
          }) profiles;

        # Global dsh directives. The loader's user-global scope is the fixed
        # path $DSH_HOME/AGENTS.md — dshHome is configurable, the file name is
        # not — and it is read before any project AGENTS.md, so this is the
        # broadest layer every session starts from. Edit ./AGENTS.md next to
        # this module, not the symlink.
        home.file = {
          ".dsh/AGENTS.md".source = ./AGENTS.md;
        }
        // lib.concatMapAttrs filesFor profiles;

        # After linkGeneration, which is what removes the store symlink an
        # older generation placed here, so the render starts from a real file
        # or from nothing. No secrets or network are involved, so unlike the
        # vllm routes this belongs in activation.
        home.activation.dshProfilePatches = lib.hm.dag.entryAfter [ "linkGeneration" ] (
          lib.concatStrings (
            lib.mapAttrsToList (name: profile: ''
              DSH_RENAMES=${lib.escapeShellArg renames} \
              DSH_DEFAULT_ROW=${lib.escapeShellArg (builtins.toJSON defaultRouteRow)} \
              DSH_NIX_ROWS=${lib.escapeShellArg (builtins.toJSON (ownedRowsFor profile))} \
              DSH_OWNED_IDS=${lib.escapeShellArg (builtins.toJSON (map (row: row.id) profile.patch))} \
                $DRY_RUN_CMD ${profilePatchRender} "$HOME/${profilePath name}/cordis.patch.yml"
            '') profiles
          )
          + lib.optionalString usesDshTui ''
            # A choice on a vLLM route's former id moves to its current one.
            tui_model="$HOME/.dsh-tui/model.json"
            if [ -f "$tui_model" ] && ${lib.getExe pkgs.jq} -e --argjson ren ${lib.escapeShellArg renames} \
              '.provider as $p | ($p | type) == "string" and ($ren | has($p))' "$tui_model" > /dev/null 2>&1; then
              if ${lib.getExe pkgs.jq} --argjson ren ${lib.escapeShellArg renames} \
                '.provider = $ren[.provider]' "$tui_model" > "$tui_model.nix.tmp"; then
                $DRY_RUN_CMD mv -f "$tui_model.nix.tmp" "$tui_model"
              else
                rm -f "$tui_model.nix.tmp"
              fi
            fi
            if [ ! -e "$HOME/.dsh-tui/model.json" ]; then
              $DRY_RUN_CMD mkdir -p "$HOME/.dsh-tui"
              $DRY_RUN_CMD cp ${dshTuiModelSeed} "$HOME/.dsh-tui/model.json.nix.tmp"
              $DRY_RUN_CMD chmod 0644 "$HOME/.dsh-tui/model.json.nix.tmp"
              $DRY_RUN_CMD mv -f "$HOME/.dsh-tui/model.json.nix.tmp" "$HOME/.dsh-tui/model.json"
            fi
          ''
        );

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
          web.plugins = lib.mkDefault [
            pkgs.dsh-herdr
            pkgs.dsh-mascot
          ];
          web.patch = lib.mkDefault [ herdrStateRow ];

          headless.bundles = lib.mkDefault [
            "@deepseek-ai/dsh-base"
            "@deepseek-ai/dsh-headless"
          ];
          headless.plugins = lib.mkDefault [
            pkgs.dsh-herdr
            pkgs.dsh-mascot
          ];
          headless.patch = lib.mkDefault [ herdrStateRow ];

          # The terminal front end, over dsh-base alone: dsh-tui replaces the
          # web app rather than layering on it, and its patch owns the
          # interactive surface. No skin — that is a web-client concern.
          tui.bundles = lib.mkDefault [ "@deepseek-ai/dsh-base" ];
          tui.plugins = lib.mkDefault [
            pkgs.dsh-tui
            pkgs.dsh-herdr
            pkgs.dsh-mascot
          ];

          tui.patch = lib.mkDefault [ herdrStateRow ];
        };

        # Ordered after sops-nix.service because that unit is what installs
        # the secrets, and home-manager starts it from `reloadSystemd` — after
        # every home.activation entry. Work that needs a secret therefore
        # cannot live in activation at all: a newly added secret is missing on
        # the activation that introduces it, and no DAG dependency fixes that,
        # because the entry named "sops-nix" is not the thing doing the work.
        #
        # WantedBy default.target so a login runs it too: the vllm catalogs it
        # discovers then refresh on boot rather than only on rebuild.
        systemd.user.services.dsh-harness-sync = {
          Unit = {
            Description = "Render dsh's vllm routes and DeepSeek credentials from sops secrets";
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
