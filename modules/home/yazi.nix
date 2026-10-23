{ inputs, ... }:
{
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

        # max-preview renders images, GIFs, video frames, PDFs, archives and
        # JSON. Pinned as a source input so `nix flake update` bumps it.
        plugins."max-preview" = "${inputs.yazi-plugins}/max-preview.yazi";

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
