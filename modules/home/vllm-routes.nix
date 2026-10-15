_: {
  flake.modules.homeManager.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      sopsSecrets = config.sops.secrets;

      # Qwen's chat template rejects `high` and anything finer than
      # low/medium/xhigh.
      qwenEfforts = [
        "none"
        "low"
        "medium"
        "xhigh"
      ];
    in
    {
      # The self-hosted vLLM endpoints, as every harness that routes to them
      # sees them. dsh and Prime Agent each render these into their own
      # provider format; spelling the endpoints once here is what keeps the
      # two from drifting apart.
      #
      # A route is one of two kinds. Behind Cloudflare Access it is three sops
      # secrets under vllm/<deployment>/ — base-url, access-client-id and
      # access-client-secret — which the renders read at runtime, after
      # sops-nix has installed them; a route whose files are not all present
      # yet is left as it is in each harness's config. On the LAN it is a
      # plain baseUrl with nothing to authenticate, reaching the renders as a
      # store file so both kinds read their URL the same way.
      options.vllm.routes = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, config, ... }:
            let
              behindAccess = config.deployment != null;
              secretFile = leaf: sopsSecrets."vllm/${config.deployment}/${leaf}".path;
              accessFile = leaf: if behindAccess then secretFile leaf else null;
            in
            {
              options = {
                displayName = lib.mkOption {
                  type = lib.types.str;
                  description = "Name the harness shows for the provider.";
                };

                deployment = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Name of the vllm/<deployment>/ group in secrets.yaml
                    holding a Cloudflare-Access route's secrets. Set this or
                    `baseUrl`, not both.
                  '';
                };

                baseUrl = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    OpenAI-compatible base URL, ending in /v1, of a route with
                    no Access in front of it. It lands in the Nix store, so it
                    must not be a secret.
                  '';
                };

                baseUrlFile = lib.mkOption {
                  type = lib.types.str;
                  readOnly = true;
                  default =
                    if behindAccess then
                      secretFile "base-url"
                    else
                      toString (pkgs.writeText "${name}-base-url" config.baseUrl);
                  description = "File holding the OpenAI-compatible base URL, ending in /v1.";
                };

                accessClientIdFile = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  readOnly = true;
                  default = accessFile "access-client-id";
                  description = "File holding the Cloudflare Access service token's client id; null for a LAN route.";
                };

                accessClientSecretFile = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  readOnly = true;
                  default = accessFile "access-client-secret";
                  description = "File holding the Cloudflare Access service token's client secret; null for a LAN route.";
                };

                envName = lib.mkOption {
                  type = lib.types.str;
                  readOnly = true;
                  default = lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] name);
                  description = ''
                    The provider id as an identifier (vllm-remote →
                    VLLM_REMOTE), for the environment variables and shell
                    variables that carry this route's values through a render.
                  '';
                };

                seedModels = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = ''
                    Models a first render writes when the endpoint cannot be
                    reached. Bootstrap only: the served catalog is discovered
                    with pkgs.vllm-catalog and always wins.
                  '';
                };

                reasoningEfforts = lib.mkOption {
                  type = lib.types.listOf (
                    lib.types.enum [
                      "none"
                      "minimal"
                      "low"
                      "medium"
                      "high"
                      "xhigh"
                      "max"
                    ]
                  );
                  default = [ ];
                  description = ''
                    The `reasoning_effort` values the route's models accept,
                    `none` meaning thinking can be turned off. Empty when the
                    route has no thinking control. vLLM validates the field
                    against the chat template, so a value missing here is a
                    400, not a no-op.
                  '';
                };

                contextWindow = lib.mkOption {
                  type = lib.types.ints.positive;
                  description = ''
                    Backstop window for a model that carries none of its own.
                    Keep it at or below the smallest window the endpoint
                    serves: too low only wastes context, too high silently
                    overruns the server.
                  '';
                };
              };
            }
          )
        );
        description = "Self-hosted vLLM endpoints, keyed by the provider id each harness registers.";
      };

      config.assertions = lib.mapAttrsToList (name: r: {
        assertion = (r.deployment == null) != (r.baseUrl == null);
        message = "vllm.routes.${name}: set exactly one of deployment (Cloudflare Access) or baseUrl (LAN).";
      }) config.vllm.routes;

      config.vllm.routes = {
        # Qwen on bytheon, straight to the Cilium LoadBalancer (kubernetes repo,
        # apps/vllm), whose policy admits the LAN and which checks no key.
        vllm-lan = {
          displayName = "vLLM (LAN)";
          baseUrl = "http://192.168.1.120:8000/v1";
          seedModels = [ "Qwen3.8-27B-FP8" ];
          reasoningEfforts = qwenEfforts;
          contextWindow = 262144;
        };

        # The same Qwen through the Kubernetes tunnel and the Reclyptor
        # account's Access, for when the LAN is out of reach.
        vllm = {
          displayName = "vLLM";
          deployment = "qwen";
          seedModels = [ "Qwen3.8-27B-FP8" ];
          reasoningEfforts = qwenEfforts;
          contextWindow = 262144;
        };

        # The DeepSeek deployment, behind a separate Cloudflare account's
        # Access on purpose.
        vllm-remote = {
          displayName = "vLLM (remote)";
          deployment = "deepseek";
          seedModels = [
            "deepseek-v4-flash-0731"
            "DeepSeek-v4.1-Flash-EXL3"
          ];
          # DeepSeek V4's encoding has exactly two thinking efforts, `high` and
          # `max` (encoding_dsv4.py asserts as much; only `max` changes the
          # prompt), and `none` selects its chat mode. vLLM's validator takes
          # every OpenAI spelling, but anything else would be a level that
          # does nothing different.
          reasoningEfforts = [
            "none"
            "high"
            "max"
          ];
          contextWindow = 600000;
        };
      };
    };
}
