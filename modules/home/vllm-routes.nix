_: {
  flake.modules.homeManager.base =
    { config, lib, ... }:
    let
      sopsSecrets = config.sops.secrets;
    in
    {
      # The self-hosted vLLM endpoints, as every harness that routes to them
      # sees them. dsh and Prime Agent each render these into their own
      # provider format; spelling the endpoints once here is what keeps the
      # two from drifting apart.
      #
      # Every endpoint sits behind Cloudflare Access, so a route is three
      # sops secrets under vllm/<deployment>/ — base-url, access-client-id and
      # access-client-secret — which the renders read at runtime, after
      # sops-nix has installed them. A route whose files are not all present
      # yet is left as it is in each harness's config.
      options.vllm.routes = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, config, ... }:
            let
              secretFile = leaf: sopsSecrets."vllm/${config.deployment}/${leaf}".path;
            in
            {
              options = {
                displayName = lib.mkOption {
                  type = lib.types.str;
                  description = "Name the harness shows for the provider.";
                };

                deployment = lib.mkOption {
                  type = lib.types.str;
                  description = "Name of the vllm/<deployment>/ group in secrets.yaml holding this route's secrets.";
                };

                baseUrlFile = lib.mkOption {
                  type = lib.types.str;
                  readOnly = true;
                  default = secretFile "base-url";
                  description = "File holding the OpenAI-compatible base URL, ending in /v1.";
                };

                accessClientIdFile = lib.mkOption {
                  type = lib.types.str;
                  readOnly = true;
                  default = secretFile "access-client-id";
                  description = "File holding the Cloudflare Access service token's client id.";
                };

                accessClientSecretFile = lib.mkOption {
                  type = lib.types.str;
                  readOnly = true;
                  default = secretFile "access-client-secret";
                  description = "File holding the Cloudflare Access service token's client secret.";
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

      config.vllm.routes = {
        # Qwen on bytheon, through the Kubernetes tunnel and the Reclyptor
        # account's Access.
        vllm = {
          displayName = "vLLM";
          deployment = "qwen";
          seedModels = [ "Qwen3.8-27B-FP8" ];
          # Its template rejects `high` and anything finer than low/medium/xhigh.
          reasoningEfforts = [
            "none"
            "low"
            "medium"
            "xhigh"
          ];
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
          reasoningEfforts = [
            "none"
            "minimal"
            "low"
            "medium"
            "high"
            "xhigh"
            "max"
          ];
          contextWindow = 600000;
        };
      };
    };
}
