{ config, pkgs, ... }: {
  xdg.configFile."yt-dlp/config".text = ''
    --remote-components ejs:github
  '';
}
