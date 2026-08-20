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

      # pi-ai's OpenAI-compatible transport will not build a request without
      # either a credential or an Authorization header, but this endpoint is
      # keyless — Cloudflare Access in front of it does the authenticating.
      # Upstream sanctions exactly this: "a keyless local server needs a
      # placeholder credential referenced by apiKeyEnv or an Authorization
      # entry in headers". Not a secret, so it is inlined rather than sops'd,
      # and it is safe from the headers-are-never-redacted caveat below.
      placeholderKey = "unused-cloudflare-access-fronts-this";

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
        del(.["llm-pi-ai"].providers.vllm.apiKeyEnv) |
        .["llm-pi-ai"].providers.vllm.defaultContextWindow = ${toString contextWindow} |
        .["llm-pi-ai"].providers.vllm.headers.Authorization = "Bearer ${placeholderKey}" |
        .["llm-pi-ai"].providers.vllm.headers["CF-Access-Client-Id"] = strenv(DSH_CF_ID) |
        .["llm-pi-ai"].providers.vllm.headers["CF-Access-Client-Secret"] = strenv(DSH_CF_SECRET) |
        .["llm-pi-ai"].providers.vllm.models = [{"id": "${model}"}] |
        .["agent-default-model"].provider = "vllm" |
        .["agent-default-model"].model = "${model}"
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
      bundlesFor =
        profile: profile.bundles ++ lib.optional (skinFor profile != null) (skinFor profile).packageName;

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
        };

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
          web.skin = lib.mkDefault "maid-atelier";
          web.bundles = lib.mkDefault [
            "@deepseek-ai/dsh-base"
            "@deepseek-ai/dsh-web-app"
          ];
          headless.bundles = lib.mkDefault [
            "@deepseek-ai/dsh-base"
            "@deepseek-ai/dsh-headless"
          ];
        };

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
    };
}
