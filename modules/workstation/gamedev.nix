_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      godot_4
      blender
      material-maker
      tiled
    ];
  };

  flake.modules.homeManager.base = { pkgs, lib, ... }: {
    # Godot discovers export templates under $XDG_DATA_HOME/godot/export_templates/<version>/.
    # Symlink the Nix-provided set there so exporting works without the manual
    # "Manage Export Templates -> Install from file" step in the editor. The templates
    # package is built from the same nixpkgs revision as godot_4, so the two stay in
    # lockstep across upgrades and the version directory always matches the editor.
    xdg.dataFile."godot/export_templates".source =
      "${pkgs.godot_4-export-templates-bin}/share/godot/export_templates";

    # Point Godot at Blender so it can import .blend files directly. Since Godot 4.3
    # this setting must be the exact executable path, and Godot's auto-detection only
    # probes FHS locations (/usr/bin/…) that don't exist on NixOS — so we set it here.
    # editor_settings-4.tres is GUI-mutable and owned by Godot, so we can't manage it
    # as a read-only symlink without breaking every other editor preference. Instead we
    # enforce just this one key idempotently on activation and leave the rest to Godot.
    # /run/current-system/sw/bin/blender is stable across rebuilds (no store-path churn).
    home.activation.godotBlenderPath = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.writeShellScript "godot-blender-path" ''
        set -euo pipefail
        settings="''${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-4.tres"
        key="filesystem/import/blender/blender_path"
        value="/run/current-system/sw/bin/blender"
        mkdir -p "$(dirname "$settings")"
        if [ ! -f "$settings" ]; then
          printf '%s\n\n%s\n%s = "%s"\n' \
            '[gd_resource type="EditorSettings" format=3]' '[resource]' "$key" "$value" \
            > "$settings"
        elif ${pkgs.gnugrep}/bin/grep -q "^$key" "$settings"; then
          ${pkgs.gnused}/bin/sed -i "s|^$key = .*|$key = \"$value\"|" "$settings"
        else
          ${pkgs.gnused}/bin/sed -i "/^\[resource\]/a $key = \"$value\"" "$settings"
        fi
      ''}
    '';
  };
}
