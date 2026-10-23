_: {
  flake.modules.homeManager.base =
    {
      pkgs,
      ...
    }:
    {
      programs.yazi = {
        enable = true;
        enableBashIntegration = false;
        enableFishIntegration = false;
        enableNushellIntegration = false;
        enableZshIntegration = false;

        # Image, GIF, video, PDF, archive and JSON previews are built into
        # yazi since 25.2.7 (preset plugins), so no plugin is installed here —
        # the preset previewers shell out to the tools below.

        # Companion tools from the official docs dependency list, added to
        # yazi's wrapper PATH. Already on the machine elsewhere: fd, rg
        # (neovim), imagemagick (forensics), ffmpeg-full, poppler-utils,
        # p7zip (system), wl-clipboard (desktop).
        extraPackages = with pkgs; [
          chafa # image and animated GIF preview
          ffmpegthumbnailer # video thumbnails
          file # mime type detection (required by yazi)
          fzf # quick file submatching
          jq # JSON preview
          unar # RAR archive listing
          zoxide # smarter cd / z jump
        ];
      };
    };
}
