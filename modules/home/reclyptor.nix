_: {
  flake.modules.homeManager.base = {
    home.username = "reclyptor";
    home.homeDirectory = "/home/reclyptor";
    home.stateVersion = "24.11";

    programs.home-manager.enable = true;
  };
}
