_: {
  # gopher64 (github.com/gopher64/gopher64) — the Nintendo 64 emulator, with
  # parallel-rdp for low-level, accurate RDP rendering on Vulkan.
  flake.modules.nixos.workstation =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.gopher64 ];
    };
}
