_: {
  flake.modules.nixos.workstation = _: {
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

        # Disables the iGPU heuristic, the only thing igpu_desiredgov feeds. It
        # reads the RAPL energy counters to decide whether the integrated GPU is
        # loaded enough to deserve the CPU's power budget, and this board does not
        # expose /sys/class/powercap/intel-rapl/.../energy_uj, so every activation
        # logged a read failure. Games run on the discrete card regardless.
        #
        # 10000 rather than the -1 the man page suggests: gamemode 1.8.2 rejects a
        # negative threshold with an error of its own and then still reads the
        # counters. The daemon short-circuits on `threshold < 10000` before
        # touching RAPL, which is the branch its own comment describes as the way
        # to turn the heuristic off.
        igpu_power_threshold = 10000;

        # Nothing on this system claims org.freedesktop.ScreenSaver — no
        # hypridle, no swayidle, and Hyprland does not implement it — so the
        # inhibit call failed with ServiceUnknown on every activation while
        # inhibiting nothing. Turn this back on if an idle daemon ever lands.
        inhibit_screensaver = 0;

        # ioprio is deliberately left at its default. GameMode logs "Skipping
        # ioprio on client: ioprio was (0) but we expected (4)" on every
        # activation because it compares against a value no process that never
        # called ioprio_set actually has, and no config value avoids that: "off"
        # is clamped back to 0 with a second error before the check that would
        # honour it. Moot regardless, since every NVMe here runs the `none`
        # scheduler, which does not arbitrate by priority.
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
