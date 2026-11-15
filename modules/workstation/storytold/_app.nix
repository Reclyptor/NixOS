# One Storytold app as a NixOS module: a `storytold.<pname>.enable` switch, off
# unless a host turns it on, and the package from _artcraft.nix behind it. Each
# app costs most of an hour to compile, so a host builds only what it asks for;
# a disabled app is never evaluated, fetched or built.
#
# `pname` is separate from the rest because it names the option, and an option
# name cannot depend on pkgs. `args` is everything else _artcraft.nix takes, as
# a function of { lib, pkgs } so an app can name its native dependencies.
pname: args:
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.storytold.${pname}.enable = lib.mkEnableOption "${pname}, from the Storytold craft suite";

  config = lib.mkIf config.storytold.${pname}.enable {
    environment.systemPackages = [
      (import ./_artcraft.nix { inherit lib pkgs; } ({ inherit pname; } // args { inherit lib pkgs; }))
    ];
  };
}
