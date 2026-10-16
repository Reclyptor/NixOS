_: {
  # Snes9x (github.com/snes9xgit/snes9x) — the SNES emulator. The GTK frontend
  # rather than the plain `snes9x` attr: that one is the bare X11 port, while
  # snes9x-gtk is the maintained desktop UI and runs natively on Wayland.
  flake.modules.nixos.workstation =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.snes9x-gtk ];
    };
}
