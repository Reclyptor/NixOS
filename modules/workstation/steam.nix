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

    # defaultgov is deliberately unset: naming a governor here makes GameMode
    # restore *that* one on exit rather than whatever was actually running, so
    # a hardcoded value silently leaves the machine parked there after every
    # session. Omitted, GameMode records the governor at activation and puts it
    # back.
    programs.gamemode.settings = {
      general = {
        renice = 10;
        desiredgov = "performance";
        igpu_desiredgov = "performance";
        inhibit_screensaver = 1;
      };
    };

    # Upstream ships every GameMode action denied by default and expects the
    # distribution to supply the grant; the NixOS module does not, so the
    # governor and /proc/sys helpers fail with "Not authorized" and GameMode is
    # active-but-inert. Matched on action id rather than the policy's
    # exec.path annotation, which carries a /nix/store path that moves on every
    # GameMode bump. gpu-helper is withheld: it drives GPU clock states and
    # upstream marks it as capable of damaging hardware.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if ((action.id == "com.feralinteractive.GameMode.governor-helper" ||
             action.id == "com.feralinteractive.GameMode.procsys-helper" ||
             action.id == "com.feralinteractive.GameMode.cpu-helper") &&
            subject.isInGroup("wheel") && subject.local && subject.active) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
