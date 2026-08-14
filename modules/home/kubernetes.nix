{ ... }: {
  flake.modules.homeManager.base =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      sops.secrets."kubernetes/config" = {
        path = "${config.home.homeDirectory}/.kube/config";
      };
    };
}
