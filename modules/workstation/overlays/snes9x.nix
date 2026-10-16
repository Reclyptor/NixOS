_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (final: prev: {
        # snes9x 1.63's GTK build compiles libjma without the target-wide
        # definitions, so SYSTEM_ZIP never reaches stream.h there and it falls
        # back to `#include "unzip.h"` — a bundled header that is not on the
        # include path when the system minizip is used. Upstream added the
        # missing target_compile_definitions in snes9xgit/snes9x#1033, after the
        # 1.63 tag. Drop this once nixpkgs carries a release that includes it.
        snes9x-gtk = prev.snes9x-gtk.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            (final.fetchpatch {
              url = "https://github.com/snes9xgit/snes9x/commit/871a88065ca2d4e218b95626b646742a40cf88ae.patch";
              hash = "sha256-NG5SxbuBFP98Qx6QZ1eIDWcwnuSvtzPL4TvjIMoha7s=";
            })
          ];
        });
      })
    ];
  };
}
