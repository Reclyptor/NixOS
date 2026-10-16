_: {
  flake.modules.homeManager.base = { config, ... }: {
    # Cargo has no config file that can relocate its own home, so this goes
    # through CARGO_HOME, which the module sets as a session variable. Data
    # home rather than cache: CARGO_HOME also holds bin/ and credentials.
    # The module always writes $CARGO_HOME/config.toml, so cargo settings
    # belong in programs.cargo.settings, not in that file.
    programs.cargo = {
      enable = true;
      package = null;
      cargoHome = "${config.xdg.dataHome}/cargo";
    };
  };
}
