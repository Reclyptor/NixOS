_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        # Hyprland 0.55+ runs a Lua config, and its IPC now evaluates `dispatch`
        # arguments as Lua, so the `dispatch workspace N` that Waybar 0.15.0 sends
        # when a workspace button is clicked fails with a syntax error and the
        # buttons do nothing. Waybar 0.16.0 detects the Lua protocol and sends
        # hl.dsp calls instead. nixos-unstable already ships Hyprland 0.57 but
        # still has Waybar 0.15.0; the 0.16.0 bump (NixOS/nixpkgs#583754) is on
        # master only. _package.nix is that commit's package verbatim, since the
        # bump also moves the vendored libcava and adds meson options, which a
        # src override alone would miss. Delete this directory once nixos-unstable
        # carries Waybar 0.16.0.
        waybar = prev.callPackage ./_package.nix { };
      })
    ];
  };
}
