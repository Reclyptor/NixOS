_: {
  # Eden (git.eden-emu.dev/eden-emu/eden) — the Nintendo Switch emulator, a
  # continuation of the yuzu/Sudachi line. It needs the console's prod.keys
  # and a firmware dump before it boots anything; both go in through its
  # Tools menu and land under ~/.local/share/eden.
  flake.modules.nixos.workstation =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.eden ];
    };
}
