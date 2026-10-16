_: {
  # shadPS4 (github.com/shadps4-emu/shadPS4) — the PS4 emulator. The PS4
  # counterpart to anyps5.nix, which only ports PS5 executables: PS4 titles
  # (CUSA…) are built against the Orbis system libraries and GNM rather than
  # the PS5 ones AnyPS5 reimplements, so it has nothing to link them to.
  #
  # The emulator itself is CLI-only now; the Qt launcher is the separate GUI
  # and runs this same core. Neither installs .pkg files any more — both take
  # an extracted game directory (the one holding eboot.bin and sce_sys/), and
  # an update goes in a sibling directory named <game dir>-UPDATE.
  #
  # LibOrbisPkg's pkgtool does that extraction, for fake PKGs only:
  #
  #   pkgtool pkg_makegp4 <game.pkg>   <games>/CUSA03173
  #   pkgtool pkg_makegp4 <update.pkg> <games>/CUSA03173-UPDATE
  #
  # pkg_makegp4 rather than pkg_extract: pkg_extract unpacks only the PFS
  # image, and sce_sys/param.sfo — which shadPS4 reads to identify the game —
  # is a PKG entry outside it. pkg_makegp4 writes both, plus a Project.gp4 the
  # emulator ignores. npbind.dat and nptitle.dat come out still encrypted;
  # shadPS4 never opens either.
  #
  # pkgtool is patched: as packaged it silently corrupts compressed PKGs, which
  # is most of them. The patch header has the details.
  flake.modules.nixos.workstation =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        shadps4
        shadps4-qtlauncher
        (liborbispkg-pkgtool.overrideAttrs (previous: {
          patches = (previous.patches or [ ]) ++ [ ./liborbispkg-pfsc-full-sector-read.patch ];
        }))
      ];
    };
}
