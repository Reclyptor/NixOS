{ inputs, ... }: {
  # Provides the flake.modules.<class>.<name> option (deferredModule attrs)
  # that every feature file contributes to.
  imports = [ inputs.flake-parts.flakeModules.modules ];

  systems = [ "x86_64-linux" ];
}
