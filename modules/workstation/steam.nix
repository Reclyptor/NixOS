_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.sessionVariables = {
      STEAM_RUNTIME = "1";
      LD_PRELOAD = "";
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

    programs.gamemode.settings = {
      general = {
        renice = 10;
        desiredgov = "performance";
        defaultgov = "powersave";
        igpu_desiredgov = "performance";
        inhibit_screensaver = 1;
      };
    };
  };
}
