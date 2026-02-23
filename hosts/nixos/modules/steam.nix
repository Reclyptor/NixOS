{ config, pkgs, ... }: {
  environment.sessionVariables = {
    STEAM_RUNTIME = "1";
    ENABLE_GAMESCOPE_WSI = "1";
  };

  environment.systemPackages =
    let
      pinnedPkgs = import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/1750f3c1c89488e2ffdd47cab9d05454dddfb734.tar.gz";
        sha256 = "1nrwlaxd0f875r2g6v9brrwmxanra8pga5ppvawv40hcalmlccm0";
      }) {
        system = pkgs.stdenv.hostPlatform.system;
      };
    in
    with pkgs; [
      steam
      gamemode
      mangohud
      pinnedPkgs.gamescope
      protonup-qt
    ]
  ;

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  programs.gamemode.enable = true;
}
