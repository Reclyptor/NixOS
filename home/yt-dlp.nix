{ config, pkgs, ... }: {
  home.file.".local/bin/ytdlp" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash

      set -euo pipefail

      GUM="${pkgs.gum}/bin/gum"
      NFS_ROOT="/data/nfs/dxp6800"
      VIDEO_FORMAT="%(upload_date)s.%(title)s.%(id)s.%(ext)s"

      declare -A CATEGORY_DIRS=(
        [YouTube]="youtube"
        [VTuber]="vtuber"
        [ASMR]="asmr"
      )

      declare -A CATEGORY_KEYS=(
        [yt]="YouTube"
        [vt]="VTuber"
        [asmr]="ASMR"
      )

      usage() {
        echo "Usage: ytdlp [category] [subfolder] [url]"
        echo ""
        echo "Run without arguments for interactive mode."
        echo ""
        echo "Categories:"
        echo "  yt    - YouTube (''${NFS_ROOT}/youtube)"
        echo "  vt    - VTuber  (''${NFS_ROOT}/vtuber)"
        echo "  asmr  - ASMR   (''${NFS_ROOT}/asmr)"
        echo ""
        echo "Examples:"
        echo "  ytdlp                                        (interactive)"
        echo "  ytdlp yt https://youtube.com/watch?v=..."
        echo "  ytdlp vt clips https://youtube.com/watch?v=..."
        exit 1
      }

      download() {
        /run/current-system/sw/bin/yt-dlp --cookies-from-browser brave \
          --remote-components ejs:github \
          --extractor-args "youtube:player-client=default" \
          --ffmpeg-location "/run/current-system/sw/bin/ffmpeg" \
          --compat-options youtube-dl \
          -f "bestvideo+bestaudio" \
          --write-thumbnail -i --add-metadata --write-info-json \
          --write-subs --embed-subs \
          --output "''${BASE_PATH}/''${VIDEO_FORMAT}" \
          --merge-output-format mkv "''${URL}"
      }

      # --- Interactive mode ---
      if [[ $# -eq 0 ]]; then
        CATEGORY=$("''${GUM}" choose --header "Select category:" "YouTube" "VTuber" "ASMR")
        BASE_PATH="''${NFS_ROOT}/''${CATEGORY_DIRS[''${CATEGORY}]}"

        if "''${GUM}" confirm "Download to a subfolder?"; then
          SUBFOLDER=$("''${GUM}" input --header "Subfolder name:" --placeholder "e.g. clips")
          if [[ -n "''${SUBFOLDER}" ]]; then
            BASE_PATH="''${BASE_PATH}/''${SUBFOLDER}"
            mkdir -p "''${BASE_PATH}"
          fi
        fi

        URL=$("''${GUM}" input --header "Video URL:" --placeholder "https://youtube.com/watch?v=..." --width 80)
        [[ -z "''${URL}" ]] && echo "Error: URL is required" && exit 1

        echo ""
        "''${GUM}" style --bold --foreground 10 "Downloading to ''${BASE_PATH}"
        echo ""

        download
        exit 0
      fi

      # --- CLI mode ---
      [[ "''${1}" == "-h" || "''${1}" == "--help" ]] && usage

      CATEGORY_KEY="''${1}"; shift
      [[ -z "''${CATEGORY_KEYS[''${CATEGORY_KEY}]+x}" ]] && echo "Error: unknown category '''''${CATEGORY_KEY}'''" && usage

      CATEGORY="''${CATEGORY_KEYS[''${CATEGORY_KEY}]}"
      BASE_PATH="''${NFS_ROOT}/''${CATEGORY_DIRS[''${CATEGORY}]}"

      if [[ $# -ge 2 ]]; then
        SUBFOLDER="''${1}"; shift
        BASE_PATH="''${BASE_PATH}/''${SUBFOLDER}"
        mkdir -p "''${BASE_PATH}"
      fi

      [[ $# -eq 0 ]] && echo "Error: URL is required" && usage
      URL="''${1}"

      download
    '';
  };
}
