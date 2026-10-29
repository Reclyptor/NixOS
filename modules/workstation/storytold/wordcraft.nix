# WordCraft — the Microsoft Word equivalent. Reads and writes DOCX and ODT, plus
# RTF, Markdown and HTML.
#
# First of the non-Adobe apps in the suite; see SPEC/storytold-office-apps.md.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "wordcraft";
          version = "0.12.0";
          hash = "sha256-LhpKmMH3WdWjheAj8m+umkNhYUSuHlkuh+ynnhTqwyQ=";
          cargoHash = "sha256-1gxWhk2Ln/V+lIiSnMOd0tE0QEYsQ5MJJmPUcDX0hhU=";
          releaseDate = "2026-10-28";
          description = "Word processor for documents, with DOCX and ODT support";
          craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";

          # Since 0.11.0 the interface translations live in storytold/craft-i18n,
          # which crates/ui-egui/build.rs embeds at the commit in craft-i18n.rev.
          craftI18nRev = "9205108cfdced5177706264038848b68b2422d2b";

          # Only the commit: unlike photocraft and deckcraft, nothing here reads a
          # BUILD_DATE, so passing one would just be an unread input.
          extraEnv = {
            WORDCRAFT_BUILD_SHA = "3de6ff95af86c19d67030cd96dba15cd6a45a25e";
          };
        })
      ];
    };
}
