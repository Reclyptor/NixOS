_: {
  # Doujin and visual-novel titles — DLsite, itch.io, anything that arrives as a
  # bare Windows executable in a zip with no launcher, no login and no store
  # client. That is the simplest shape a Windows game comes in, so it gets one
  # generic command rather than a Nix entry per title: adding a game means
  # unzipping it and pointing `jpgame` at its exe.
  #
  # One shared prefix, not one per game. These titles are small, overwhelmingly
  # single-player, and mostly touch nothing but their own directory; a prefix
  # each would mean a few hundred megabytes of duplicated Wine tree apiece for
  # isolation they do not need. If a game ever does corrupt the prefix, deleting
  # it costs nothing — none of the games live inside it.
  flake.modules.nixos.workstation =
    {
      config,
      pkgs,
      ...
    }:
    let
      root = "/data/nvme/jpgames";
      protonPackage = pkgs.proton-ge-bin;

      # The patched gamemoderun from gamemode.nix, not pkgs.gamemode — the
      # upstream script preloads by soname and silently does nothing here.
      gamemoderun = "${config.programs.gamemode.package}/bin/gamemoderun";
    in
    {
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "jpgame" ''
          set -euo pipefail

          if [ $# -lt 1 ]; then
            echo "usage: jpgame <path-to-game.exe> [args...]" >&2
            echo "" >&2
            echo "Runs a Windows game under Proton in the shared Japanese-locale" >&2
            echo "prefix at ${root}/prefix." >&2
            exit 2
          fi

          target=$1
          shift

          if [ ! -f "$target" ]; then
            echo "jpgame: no such file: $target" >&2
            exit 1
          fi

          # Absolute, because we are about to change directory.
          target=$(${pkgs.coreutils}/bin/realpath -- "$target")

          # Run from the game's own directory. Doujin games are built assuming
          # the working directory IS the install directory and load their data
          # with relative paths; started from anywhere else they abort on a
          # missing archive, or silently come up with no graphics and no sound.
          # This is the single most common reason one of these "does not work"
          # under Wine, and it has nothing to do with Wine.
          cd -- "$(${pkgs.coreutils}/bin/dirname -- "$target")"

          export WINEPREFIX=${root}/prefix

          # The whole point of this wrapper. These games are routinely built
          # against Shift-JIS and ask the OS what locale it is in; answer "C" and
          # every string renders as mojibake. ja_JP.UTF-8 is generated for this
          # host in modules/common/locale.nix — without that this export names a
          # locale that does not exist and achieves nothing.
          #
          # LC_ALL rather than LANG alone, because it is the only one that
          # overrides the LC_* settings locale.nix pins to en_US; LANG is the
          # weakest of the three and loses to them.
          export LANG=ja_JP.UTF-8
          export LC_ALL=ja_JP.UTF-8

          export GAMEID=umu-default
          export STORE=none
          export PROTONPATH=${protonPackage.steamcompattool}

          # Shader caches on the dataset rather than ~/.cache.
          export DXVK_STATE_CACHE_PATH=${root}/cache
          export DXVK_SHADER_CACHE_PATH=${root}/cache
          export __GL_SHADER_DISK_CACHE=1
          export __GL_SHADER_DISK_CACHE_PATH=${root}/cache
          export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1

          exec ${gamemoderun} ${pkgs.umu-launcher}/bin/umu-run "$target" "$@"
        '')
      ];
    };
}
