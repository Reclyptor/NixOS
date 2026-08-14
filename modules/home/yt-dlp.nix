_: {
  flake.modules.homeManager.base = { pkgs, ... }: {
    home.file.".local/bin/ytdlp" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash

        set -euo pipefail

        GUM="${pkgs.gum}/bin/gum"
        NFS_ROOT="/data/nfs/dxp6800"
        VIDEO_FORMAT="%(upload_date)s.%(title)s.%(id)s.%(ext)s"

        declare -A CATEGORY_DIRS=(
          [CatA]="cat-a"
          [CatB]="cat-b"
          [CatC]="cat-c"
          [CatD]="cat-d"
        )

        declare -A CATEGORY_KEYS=(
          [a]="CatA"
          [b]="CatB"
          [c]="CatC"
          [d]="CatD"
        )

        declare -A CATEGORY_COOKIES=(
          [CatA]="''${HOME}/.config/yt-dlp/cookies.txt"
          [CatB]="''${HOME}/.config/yt-dlp/cookies.txt"
          [CatC]="''${HOME}/.config/yt-dlp/cookies.txt"
          [CatD]="''${HOME}/.config/yt-dlp/d-cookies.txt"
        )

        usage() {
          echo "Usage: ytdlp [category] [subfolder] [url]"
          echo ""
          echo "Run without arguments for interactive mode."
          echo ""
          echo "Categories:"
          echo "  a     - CatA (''${NFS_ROOT}/cat-a)"
          echo "  b     - CatB (''${NFS_ROOT}/cat-b)"
          echo "  c     - CatC (''${NFS_ROOT}/cat-c)"
          echo "  d     - CatD (''${NFS_ROOT}/cat-d)"
          echo ""
          echo "Examples:"
          echo "  ytdlp                                        (interactive)"
          echo "  ytdlp <category> <url>"
          echo "  ytdlp <category> <subfolder> <url>"
          exit 1
        }

        download() {
          COOKIES_FILE="''${CATEGORY_COOKIES[''${CATEGORY}]}"
          if [[ ! -f "''${COOKIES_FILE}" ]]; then
            echo "Error: cookies file not found at ''${COOKIES_FILE}"
            echo "Export ''${CATEGORY} cookies from a private Brave window using the 'Get cookies.txt LOCALLY' extension."
            exit 1
          fi

          # Pick the single best audio track per language (Japanese, English,
          # Spanish) for whichever subset the video has, falling back to the best
          # audio. ba[...] takes one best track per filter; mergeall would instead
          # embed every quality variant of every language.
          local JA="ba[language^=ja]" EN="ba[language^=en]" ES="ba[language^=es]"
          local FORMAT="bv*+''${JA}+''${EN}+''${ES}/bv*+''${JA}+''${EN}/bv*+''${JA}+''${ES}/bv*+''${EN}+''${ES}/bv*+''${JA}/bv*+''${EN}/bv*+''${ES}/bv*+ba/b"

          ${pkgs.yt-dlp}/bin/yt-dlp --cookies "''${COOKIES_FILE}" \
            --extractor-args "youtube:player-client=default" \
            --ffmpeg-location "${pkgs.ffmpeg-full}/bin/ffmpeg" \
            -f "''${FORMAT}" \
            --audio-multistreams \
            --embed-thumbnail --convert-thumbnails jpg \
            -i --add-metadata --write-info-json \
            --write-subs --write-auto-subs --embed-subs \
            --sub-langs "en,es,ja" --compat-options no-keep-subs \
            --output "''${BASE_PATH}/''${VIDEO_FORMAT}" \
            --merge-output-format mkv "''${URL}"
        }

        # --- Interactive mode ---
        if [[ $# -eq 0 ]]; then
          CATEGORY=$("''${GUM}" choose --header "Select category:" "CatA" "CatB" "CatC" "CatD")
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
  };
}
