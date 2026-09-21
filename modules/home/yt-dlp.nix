_: {
  flake.modules.homeManager.base = { pkgs, ... }: {
    home.file.".local/bin/ytdlp" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash

        set -euo pipefail

        GUM="${pkgs.gum}/bin/gum"
        NFS_ROOT="/data/nfs/dxp4800/videos"
        VIDEO_FORMAT="%(upload_date)s.%(title)s.%(id)s.%(ext)s"

        # The category table -- which directories exist and which cookies each
        # needs -- lives in the sops secret rather than here. This repository is
        # public, and the set of category names is itself the thing worth not
        # publishing; the mechanism is safe to show, the list is not.
        #
        # sops-nix decrypts it at activation. A missing file means that unit did
        # not run or could not decrypt, so say that rather than failing later on
        # an unbound array subscript.
        CATEGORY_CONF="''${HOME}/.config/sops/secrets/ytdlp/categories"
        if [[ ! -r "''${CATEGORY_CONF}" ]]; then
          echo "Error: category table not readable: ''${CATEGORY_CONF}" >&2
          echo "It is decrypted by sops-nix at activation -- check: systemctl --user status sops-nix" >&2
          exit 1
        fi
        # shellcheck source=/dev/null
        source "''${CATEGORY_CONF}"

        # display name -> short key, so the usage text can be printed from the
        # table instead of repeating it.
        declare -A SHORT_OF=()
        for KEY in "''${!CATEGORY_KEYS[@]}"; do
          SHORT_OF["''${CATEGORY_KEYS[''${KEY}]}"]="''${KEY}"
        done

        export_help() {
          {
            echo "Sign in to ''${CATEGORY} inside a private Brave window, then export that site's cookies"
            echo "to ''${COOKIES_FILE} with the 'Get cookies.txt LOCALLY' extension."
            echo "A private window starts signed out, so exporting before signing in yields a guest jar."
          } >&2
        }

        # Field 6 of the tab-separated Netscape format is the cookie name. HttpOnly
        # rows carry a '#HttpOnly_' domain prefix and must not be skipped as
        # comments; auth_token and LOGIN_INFO are both HttpOnly.
        has_cookie() {
          ${pkgs.gawk}/bin/awk -F'\t' -v name="''${2}" '
            /^#HttpOnly_/ || $0 !~ /^#/ { if (NF == 7 && $6 == name) found = 1 }
            END { exit !found }
          ' "''${1}"
        }

        # Warns rather than blocks: a guest session still downloads public media,
        # and refusing the run would trade a confusing failure for a needless one.
        check_cookies() {
          COOKIES_FILE="''${CATEGORY_COOKIES[''${CATEGORY}]}"

          if [[ ! -f "''${COOKIES_FILE}" ]]; then
            echo "Error: cookies file not found at ''${COOKIES_FILE}" >&2
            export_help
            exit 1
          fi

          local MISSING=() NAME FOUND
          for NAME in ''${CATEGORY_COOKIES_REQUIRED[''${CATEGORY}]}; do
            if ! has_cookie "''${COOKIES_FILE}" "''${NAME}"; then
              MISSING+=("''${NAME}")
            fi
          done

          local ANY="''${CATEGORY_COOKIES_ANY[''${CATEGORY}]}"
          if [[ -n "''${ANY}" ]]; then
            FOUND=""
            for NAME in ''${ANY}; do
              if has_cookie "''${COOKIES_FILE}" "''${NAME}"; then FOUND=1; break; fi
            done
            if [[ -z "''${FOUND}" ]]; then MISSING+=("one of ''${ANY}"); fi
          fi

          if (( ''${#MISSING[@]} > 0 )); then
            {
              echo "Warning: ''${COOKIES_FILE} is not a signed-in ''${CATEGORY} session."
              printf '  missing: %s\n' "''${MISSING[@]}"
              echo "Public media will still download. Anything private, age-gated or"
              echo "follower-only will fail, and yt-dlp will report it as a missing video."
            } >&2
            export_help
            echo "" >&2
          fi
        }

        usage() {
          echo "Usage: ytdlp [category] [subfolder] [url]"
          echo ""
          echo "Run without arguments for interactive mode."
          echo ""
          echo "Categories:"
          # Printed from the table, not restated here: a second copy of the list
          # drifts, and it would put the category names back in this file.
          for NAME in "''${CATEGORY_ORDER[@]}"; do
            printf "  %-5s - %s (%s/%s)\n" \
              "''${SHORT_OF[''${NAME}]}" "''${NAME}" "''${NFS_ROOT}" "''${CATEGORY_DIRS[''${NAME}]}"
          done
          echo ""
          echo "Examples:"
          echo "  ytdlp                                        (interactive)"
          echo "  ytdlp <category> <url>"
          echo "  ytdlp <category> <subfolder> <url>"
          exit 1
        }

        download() {
          # yt-dlp rewrites whatever jar it is handed once a run finishes, which is
          # how an expired export gets replaced in place by the guest cookies that
          # run picked up. Hand it a copy so the export stays the one source of
          # truth. mktemp creates at 0600; these are live credentials.
          JAR=$(${pkgs.coreutils}/bin/mktemp -t ytdlp-cookies.XXXXXXXX)
          trap '${pkgs.coreutils}/bin/rm -f "''${JAR}"' EXIT
          ${pkgs.coreutils}/bin/cp "''${COOKIES_FILE}" "''${JAR}"

          # Pick the single best audio track per language (Japanese, English,
          # Spanish) for whichever subset the video has, falling back to the best
          # audio. ba[...] takes one best track per filter; mergeall would instead
          # embed every quality variant of every language.
          local JA="ba[language^=ja]" EN="ba[language^=en]" ES="ba[language^=es]"
          local FORMAT="bv*+''${JA}+''${EN}+''${ES}/bv*+''${JA}+''${EN}/bv*+''${JA}+''${ES}/bv*+''${EN}+''${ES}/bv*+''${JA}/bv*+''${EN}/bv*+''${ES}/bv*+ba/b"

          ${pkgs.yt-dlp}/bin/yt-dlp --cookies "''${JAR}" \
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
          CATEGORY=$("''${GUM}" choose --header "Select category:" "''${CATEGORY_ORDER[@]}")
          BASE_PATH="''${NFS_ROOT}/''${CATEGORY_DIRS[''${CATEGORY}]}"
          check_cookies

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
        check_cookies

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
