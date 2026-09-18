_: {
  flake.modules.nixos.workstation =
    { pkgs, ... }:
    {
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

      # gamemoderun as shipped cannot reach the daemon from inside a Steam game.
      # It preloads libgamemodeauto by soname and leaves the lookup to an
      # LD_LIBRARY_PATH it exports, but Steam runs games under pressure-vessel
      # (the Steam Linux Runtime container), which rebuilds LD_LIBRARY_PATH out
      # of the container's own directories and drops every host entry. The
      # preload itself survives, so libgamemodeauto loads and then fails its
      # dlopen of libgamemode.so.0 — "gamemodeauto: dlopen failed -
      # libgamemode.so: cannot open shared object file" in every game log, while
      # the game ran at stock priority and governor.
      #
      # The container does expose /nix/store, so the fix is to stop relying on a
      # search path at all: preload both libraries by absolute path, which also
      # satisfies the later dlopen, since it resolves against the soname already
      # loaded. LD_LIBRARY_PATH is then unnecessary and no longer exported, so
      # games no longer inherit these directories on their library path.
      #
      # Patched here rather than alongside as a second launcher, so that every
      # existing `gamemoderun %command%` launch option is fixed where it stands.
      #
      # The library has to match the architecture of the process it is preloaded
      # into or ld.so rejects it with a wrong-ELF-class error, and the soname
      # indirection that used to handle that is what broke, so read the class off
      # the target binary instead. Steam's launcher chain is 64-bit even for a
      # 32-bit game, and that chain is what registers with the daemon; the renice
      # is inherited by everything below it.
      programs.gamemode.package = pkgs.gamemode.overrideAttrs (previous: {
        postFixup = (previous.postFixup or "") + ''
          cat > $out/bin/gamemoderun <<'GAMEMODERUN'
          #!${pkgs.runtimeShell}
          # Helper script to launch games with gamemode.
          # Rewritten by modules/workstation/gamemode.nix; see the comment there.

          gamemode_libdir=${builtins.placeholder "lib"}/lib
          gamemode_target=$(command -v "$1" 2>/dev/null)

          if [ -n "$gamemode_target" ] && [ "$(${pkgs.coreutils}/bin/od -An -t u1 -j 4 -N 1 -- "$gamemode_target" | ${pkgs.coreutils}/bin/tr -d ' ')" = 1 ]; then
            gamemode_libdir=${pkgs.pkgsi686Linux.gamemode.lib}/lib
          fi

          LD_PRELOAD="$gamemode_libdir/libgamemode.so.0:$gamemode_libdir/libgamemodeauto.so.0''${LD_PRELOAD:+:$LD_PRELOAD}"

          exec env LD_PRELOAD="$LD_PRELOAD" $GAMEMODERUNEXEC "$@"
          GAMEMODERUN
          chmod +x $out/bin/gamemoderun
        '';
      });
    };
}
