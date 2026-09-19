_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (
        final: _prev:
        let
          # The shim has to match the architecture of the process it is preloaded
          # into or ld.so rejects it outright, and 15 of the native games here
          # still ship a 32-bit tree, so both are built and the launcher picks.
          shim =
            pkgs:
            pkgs.runCommandCC "steam-wmclass-shim-${pkgs.stdenv.hostPlatform.linuxArch}"
              {
                buildInputs = [
                  pkgs.libx11
                  pkgs.xorgproto
                ];
                meta.description = "Forces a Steam game's X11 window class to steam_app_<appid>";
              }
              ''
                mkdir -p $out/lib
                $CC -shared -fPIC -O2 -Wall -Wextra -ldl \
                  -o $out/lib/libsteamwmclass.so ${./shim.c}
              '';
        in
        {
          # Launcher rather than a bare LD_PRELOAD entry in the launch options,
          # because which build is correct is only knowable from the binary Steam
          # is about to run. Naming the wrong one is not a quiet failure: ld.so
          # prints a wrong-ELF-class error into every game's log and preloads
          # nothing.
          #
          # This sits in front of gamemoderun rather than behind it so that
          # gamemoderun still receives the game binary as $1 -- its own 32/64-bit
          # detection reads that argument, and handing it a shell script instead
          # would silently cost 32-bit games their GameMode registration.
          steam-wmclass = final.writeShellScriptBin "steam-wmclass-run" ''
            shim=${shim final}/lib/libsteamwmclass.so

            # The first ELF among the arguments is the game; anything ahead of it
            # is launcher plumbing. Ren'Py and friends are launched through a
            # shell script and hit none of this, which is correct -- those pick
            # their 64-bit tree on a 64-bit host, and that is the default.
            for candidate in "$@"; do
              [ -f "$candidate" ] || continue
              [ "$(${final.coreutils}/bin/od -An -t x1 -N 4 -- "$candidate" | ${final.coreutils}/bin/tr -d ' \n')" = "7f454c46" ] || continue
              if [ "$(${final.coreutils}/bin/od -An -t u1 -j 4 -N 1 -- "$candidate" | ${final.coreutils}/bin/tr -d ' ')" = 1 ]; then
                shim=${shim final.pkgsi686Linux}/lib/libsteamwmclass.so
              fi
              break
            done

            exec env LD_PRELOAD="$shim''${LD_PRELOAD:+:$LD_PRELOAD}" "$@"
          '';
        }
      )
    ];
  };
}
