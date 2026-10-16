_: {
  # Dolphin (github.com/dolphin-emu/dolphin) — the GameCube and Wii emulator.
  # No BIOS needed; it HLEs the IPL and boots disc images directly.
  flake.modules.nixos.workstation =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.dolphin-emu ];
    };
}
