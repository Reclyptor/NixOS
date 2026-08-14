_: {
  flake.modules.homeManager.base =
    {
      config,
      ...
    }:
    {
      sops.secrets."kubernetes/config" = {
        path = "${config.home.homeDirectory}/.kube/config";
      };
    };
}
