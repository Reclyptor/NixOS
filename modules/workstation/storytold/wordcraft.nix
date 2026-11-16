# WordCraft — the Microsoft Word equivalent. Reads and writes DOCX and ODT, plus
# RTF, Markdown and HTML.
#
# First of the non-Adobe apps in the suite; see SPEC/storytold-office-apps.md.
_: {
  flake.modules.nixos.workstation = import ./_app.nix "wordcraft" (
    { pkgs, ... }: {
      version = "0.18.1";
      hash = "sha256-n8BQIiX6C3D8pd8pil/reM/ffSW+cPEsI/OuQSUrYus=";
      cargoHash = "sha256-gsiSbjdpjKKtWfYr2xcyLiGWamy7qGGSKOraRvnaVAM=";
      releaseDate = "2026-11-12";
      description = "Word processor for documents, with DOCX and ODT support";
      craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";

      # Since 0.11.0 the interface translations live in storytold/craft-i18n,
      # which crates/ui-egui/build.rs embeds at the commit in craft-i18n.rev.
      craftI18nRev = "1e515422afdda2f317af430c1f9d68a5f83935b4";

      # fontique, new in this release's text stack, finds system fonts and
      # fallbacks by dlopening libfontconfig.so.1 (its fontconfig-dlopen
      # feature), so the build needs neither pkg-config nor the headers. Without
      # the library it reports no system fonts rather than failing.
      extraRuntimeLibraries = [ pkgs.fontconfig ];

      # Only the commit: unlike photocraft and deckcraft, nothing here reads a
      # BUILD_DATE, so passing one would just be an unread input.
      extraEnv = {
        WORDCRAFT_BUILD_SHA = "079f478bd85df7bcc567e3bafa7d7219096f9c3c";
      };
    }
  );
}
