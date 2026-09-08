_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    # steam is deliberately absent: programs.steam below installs its own
    # package and steam-run. Adding bare pkgs.steam here collides with it on
    # bin/steam and the bare one wins, which costs the FHS environment
    # everything programs.steam.fontPackages folds in from fonts.packages. The
    # Steam Linux Runtime container then exports that fontless environment to
    # steamwebhelper and the client UI draws every CJK codepoint as tofu.
    environment.systemPackages = with pkgs; [
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
  };
}
