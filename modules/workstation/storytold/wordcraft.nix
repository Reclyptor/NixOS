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
          version = "0.8.0";
          hash = "sha256-5zT+XjveKuuqaSsJnKZjerai0TaBO6s7LhrWKrvNcSU=";
          cargoHash = "sha256-Dvjl82GeD/lxrRMCOQJm8pxbVctSeMiRhtmUWpDjziE=";
          releaseDate = "2026-10-18";
          description = "Word processor for documents, with DOCX and ODT support";
          craftFontsRev = "8dcdacd5153e64560d109541a47d806f26f048c0";

          # Only the commit: unlike photocraft and deckcraft, nothing here reads a
          # BUILD_DATE, so passing one would just be an unread input.
          extraEnv = {
            WORDCRAFT_BUILD_SHA = "f2e15cf8f899a79899a2d9595ca4ce7df1e5ea22";
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
