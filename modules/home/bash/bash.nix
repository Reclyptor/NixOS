_: {
  flake.modules.homeManager.base = {
    programs.bash = {
      enable = true;
      enableCompletion = true;
      shellOptions = [
        "nullglob"
      ];
    };
  };
}
