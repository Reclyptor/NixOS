_: {
  flake.modules.nixos.workstation =
    { pkgs, ... }:
    {
      # OBS gets its own module rather than a bare entry in apps.nix because
      # NVENC does not work without the wrapper below, and a package list has
      # nowhere to explain why.
      #
      # THE BUG: obs-studio decides whether NVENC exists by running a separate
      # probe binary, bin/obs-nvenc-test, and believing its verdict. That probe
      # is built without the graphics driver directory on its runpath, while the
      # plugin that does the actual encoding has it:
      #
      #   obs-nvenc.so      RUNPATH  /run/opengl-driver/lib:...   correct
      #   obs-nvenc-test    RUNPATH  <glibc only>                 the bug
      #
      # So the probe cannot dlopen libnvidia-encode.so.1 and reports
      # `reason=nvenc_lib, nvenc_supported=false`; OBS then disables hardware
      # encoding entirely and logs "NVENC not supported". The component that
      # would have done the work is fine — only the one that decides whether to
      # load it is broken. Run by hand with the directory on its library path,
      # that same probe answers `nvenc_ver=13.0, nvenc_devices=1,
      # latest_architecture_name=Blackwell`.
      #
      # THE FIX: put the driver directory on OBS's library path so the probe it
      # spawns inherits it. LD_LIBRARY_PATH is searched ahead of DT_RUNPATH, so
      # this reaches a binary whose runpath is not being rebuilt.
      #
      # Wrapping rather than patching the runpath is a deliberate trade.
      # Patching it with overrideAttrs would be the more literal repair, but it
      # rebuilds obs-studio — a 4 GB closure that is otherwise a cache hit —
      # from source to change one string, and the result would behave exactly as
      # this does. The real repair belongs upstream in nixpkgs, which should give
      # obs-nvenc-test the same runpath it already gives obs-nvenc.so.
      #
      # symlinkJoin keeps that cache hit: the package is symlinked, not rebuilt,
      # and only bin/obs is replaced by the wrapper. The desktop entry ships
      # `Exec=obs` rather than an absolute store path, so launching OBS from the
      # menu resolves through PATH and gets the wrapper too.
      environment.systemPackages = [
        (pkgs.symlinkJoin {
          name = "obs-studio-nvenc-${pkgs.obs-studio.version}";
          paths = [ pkgs.obs-studio ];
          nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
          postBuild = ''
            wrapProgram $out/bin/obs \
              --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib
          '';
          inherit (pkgs.obs-studio) meta;
        })
      ];
    };
}
