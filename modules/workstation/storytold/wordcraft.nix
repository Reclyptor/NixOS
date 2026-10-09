# WordCraft — the Microsoft Word equivalent. Reads and writes DOCX and ODT, plus
# RTF, Markdown and HTML.
#
# First of the five non-Adobe apps in the suite; see SPEC/storytold-office-apps.md.
_: {
  flake.modules.nixos.workstation =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        (import ./_artcraft.nix { inherit lib pkgs; } {
          pname = "wordcraft";
          version = "0.3.0";
          hash = "sha256-uhePuWSXq6uybLviJg4H2Qlb5mlV4OPwryT2vqq+9zU=";
          cargoHash = "sha256-gQvzoEhvC4C1ZpQmr6E4zjRJlVqm54/N2kYe38GaAzs=";
          releaseDate = "2026-10-08";
          description = "Word processor for documents, with DOCX and ODT support";

          # Only the commit: unlike photocraft and deckcraft, nothing here reads a
          # BUILD_DATE, so passing one would just be an unread input.
          extraEnv = {
            WORDCRAFT_BUILD_SHA = "7584b9b2930ffddfe7db96b6eba977262e55135c";
          };
        })
      ];
    };
}
