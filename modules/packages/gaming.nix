{ config, pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages =
    let
      pinnedPkgs = import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/1750f3c1c89488e2ffdd47cab9d05454dddfb734.tar.gz";
        sha256 = "1nrwlaxd0f875r2g6v9brrwmxanra8pga5ppvawv40hcalmlccm0";
      }) {
        system = pkgs.system; # ← THIS IS THE FIX
      };
    in
    with pkgs; [
      steam
      mangohud
      pinnedPkgs.gamescope
      protonup-qt
    ]
  ;
}
