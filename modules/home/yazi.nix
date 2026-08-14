{ ... }: {
  flake.modules.homeManager.base =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      programs.yazi = {
        enable = true;
        enableBashIntegration = true;
        shellWrapperName = "y";
      };
    };
}
