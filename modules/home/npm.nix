_: {
  flake.modules.homeManager.base = { config, ... }: {
    # An environment variable rather than programs.npm: that module writes
    # ~/.npmrc (back into the home root) unless home.preferXdgDirectories,
    # which would relocate other modules' files too. Everything npm keeps in
    # ~/.npm (_cacache, _npx, _logs, sharp's prebuilds) derives from its
    # cache setting, so this one value moves all of it.
    home.sessionVariables.NPM_CONFIG_CACHE = "${config.xdg.cacheHome}/npm";
  };
}
