{ config, pkgs, ... }: {
  environment.sessionVariables = {
    STEAM_RUNTIME = "1";
  };

  environment.systemPackages = with pkgs; [
    steam
    gamemode
    mangohud
    protonup-qt
  ];

  programs.steam = {
    enable = true;
    gamescopeSession.enable = false;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  programs.gamemode.enable = true;
}
