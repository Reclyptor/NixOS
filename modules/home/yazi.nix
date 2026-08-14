_: {
  flake.modules.homeManager.base = _: {
    programs.yazi = {
      enable = true;
      enableBashIntegration = true;
      shellWrapperName = "y";
    };
  };
}
