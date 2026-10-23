{ inputs, ... }:
let
  # nixpkgs f903b88 bumped patchelf 0.15.2 -> 0.19.2. 0.19.2's segment rewrite
  # grows the first PT_LOAD of NVIDIA's binaries (--interpreter alone
  # triggers it, so no rpath or flag avoids it), and the rebuilt glibc loader
  # segfaults on that layout: every patched binary dumps core in dl_main,
  # which took nvidia-power-limit.service down and failed every switch with
  # status 4. Don't run these binaries through the broken rewrite at all:
  # replace them with wrappers that exec NVIDIA's untouched copies (origBin,
  # already shipped for containers) through the system loader with the driver
  # lib dir on its search path.
  nvidiaBinFix = final: prev: {
    linuxPackages = prev.linuxPackages.extend (lfinal: lprev: {
      nvidiaPackages = builtins.mapAttrs (name: pkg:
        if final.lib.isDerivation pkg then
          pkg.overrideAttrs (old: {
            postInstall =
              (if old.postInstall or null == null then "" else old.postInstall)
              + ''
                for i in nvidia-cuda-mps-control nvidia-cuda-mps-server nvidia-smi nvidia-debugdump nvidia-powerd; do
                  if [ -e "$bin/origBin/$i" ] && [ -e "$bin/bin/$i" ]; then
                    printf '#!/bin/sh\nexec %s --library-path %s %s "$@"\n' \
                      '${final.glibc}/lib/ld-linux-x86-64.so.2' \
                      "$out/lib" \
                      "$bin/origBin/$i" > "$bin/bin/$i"
                  fi
                done
              '';
          })
        else pkg) lprev.nvidiaPackages;
    });
  };
  buildFixes = _: {
    nixpkgs.overlays = [
      inputs."rust-overlay".overlays.buildFixes
      nvidiaBinFix
    ];
  };
in
{
  flake.modules.nixos.server = buildFixes;
  flake.modules.nixos.workstation = buildFixes;
}
