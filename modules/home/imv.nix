_: {
  flake.modules.homeManager.base =
    { config, ... }:
    {
      programs.imv.enable = true;

      # imv only loads a config from ~/.config/imv/config (or ~/.imv_config,
      # /etc/imv_config) and its compiled-in binds lack rotate, fullscreen,
      # overlay and others. Install the reference config the package ships so
      # the full default bind set is live and tracks upstream on every bump.
      xdg.configFile."imv/config".source = "${config.programs.imv.package}/etc/imv_config";
    };
}
