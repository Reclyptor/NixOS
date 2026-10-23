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
          version = "0.10.0";
          hash = "sha256-wvumEkKulRHPr2AxtfYZCyrN7OWiek4uNqDMY4k3FmM=";
          cargoHash = "sha256-xHXw/TYSlw1tERplmcS4WHRrhmVDIOvpQvJcUmJFCcg=";
          releaseDate = "2026-10-22";
          description = "Word processor for documents, with DOCX and ODT support";
          craftFontsRev = "8dcdacd5153e64560d109541a47d806f26f048c0";

          # Only the commit: unlike photocraft and deckcraft, nothing here reads a
          # BUILD_DATE, so passing one would just be an unread input.
          extraEnv = {
            WORDCRAFT_BUILD_SHA = "9130181a5fdaee2293e67756fd5458c601489f3c";
          };

          # This tagged Unix-only test creates a deliberately non-UTF-8 name.
          # stdenv's /build is on this host's ZFS utf8only dataset, which rejects
          # it; /dev/shm accepts raw filename bytes. Set this in preCheck because
          # stdenv initializes TMPDIR after the derivation environment.
          preCheck = ''
            export TMPDIR=/dev/shm
          '';
        })
      ];
    };
}
