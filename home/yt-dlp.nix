{ config, pkgs, ... }: 
let
  mkYtDlpScript = basePath: ''
    #!/usr/bin/env bash

    BASE_PATH="${basePath}"
    VIDEO_FORMAT="%(upload_date)s.%(title)s.%(id)s.%(ext)s"

    if [[ -n "''${1}" ]]; then
      mkdir -p "''${BASE_PATH}/''${1}"
      BASE_PATH="''${BASE_PATH}/''${1}"
    fi
    /run/current-system/sw/bin/yt-dlp --cookies-from-browser brave \
           --extractor-args "youtube:player-client=default,tv_simply" \
           --ffmpeg-location "/run/current-system/sw/bin/ffmpeg" \
           --compat-options youtube-dl  \
           -f "bv*[ext=mkv]+ba[ext=m4a]/bv*[ext=mp4]+ba[ext=m4a]/best" \
           --write-thumbnail -i --add-metadata --write-info-json \
           --output "''${BASE_PATH}/''${VIDEO_FORMAT}" \
           --merge-output-format mp4 "''${2}"
  '';
in {
  xdg.configFile."yt-dlp/config".text = ''
    --remote-components ejs:github
  '';

  home.file.".local/bin/ytdlp" = {
    executable = true;
    text = mkYtDlpScript "/data/nfs/dxp6800/youtube";
  };

  home.file.".local/bin/vtdlp" = {
    executable = true;
    text = mkYtDlpScript "/data/nfs/dxp6800/vtuber";
  };

  home.file.".local/bin/asmrdlp" = {
    executable = true;
    text = mkYtDlpScript "/data/nfs/dxp6800/asmr";
  };
}
