_: {
  flake.modules.homeManager.base = _: {
    programs.yazi = {
      enable = true;
      enableBashIntegration = false;
      enableFishIntegration = false;
      enableNushellIntegration = false;
      enableZshIntegration = false;
    };
  };
}
