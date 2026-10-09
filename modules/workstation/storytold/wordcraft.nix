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
          version = "0.7.0";
          hash = "sha256-SfrnSydUVuh+3tJ69OINsc1thkubgVh8aEVBfZyXmsM=";
          cargoHash = "sha256-D/CRhDoUbKvz/ev8NKRm2aDEyOA4NL5mdnx+O+iXHRI=";
          releaseDate = "2026-10-14";
          description = "Word processor for documents, with DOCX and ODT support";
          craftFontsRev = "8dcdacd5153e64560d109541a47d806f26f048c0";

          # Only the commit: unlike photocraft and deckcraft, nothing here reads a
          # BUILD_DATE, so passing one would just be an unread input.
          extraEnv = {
            WORDCRAFT_BUILD_SHA = "fc41918814f62645b6746ed68e71e8c2c2e85d6f";
          };
        })
      ];
    };
}
