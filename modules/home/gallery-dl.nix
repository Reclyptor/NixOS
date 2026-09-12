_: {
  flake.modules.homeManager.base =
    { pkgs, ... }:
    {
      home.file.".local/bin/pixiv" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          set -euo pipefail

          GUM="${pkgs.gum}/bin/gum"
          GALLERY_DL="${pkgs.gallery-dl}/bin/gallery-dl"
          JQ="${pkgs.jq}/bin/jq"
          MKTEMP="${pkgs.coreutils}/bin/mktemp"

          # gallery-dl's ugoira postprocessor shells out to ffmpeg by name rather
          # than through a configurable path, so put ours on PATH instead of
          # trying to thread a store path through its config.
          export PATH="${pkgs.ffmpeg-full}/bin:''${PATH}"

          NFS_ROOT="/data/nfs/dxp4800"
          BASE_PATH="''${NFS_ROOT}/pixiv"
          CONFIG="''${HOME}/.config/gallery-dl/config.json"

          # Unlike the sites ytdlp handles, pixiv is not cookie-authenticated here:
          # gallery-dl talks to the pixiv *app* API, which takes an OAuth refresh
          # token and nothing else. There is no guest mode to fall back to -- a
          # missing token aborts every run with "AuthenticationError:
          # 'refresh-token' required" before a single file is fetched. So this is a
          # hard stop with instructions rather than the warning ytdlp gives for a
          # stale cookie jar, because there is no partial success to preserve.
          auth_help() {
            {
              echo "Run '${pkgs.gallery-dl}/bin/gallery-dl oauth:pixiv' and follow the browser flow."
              echo "It prints a refresh token; put it in ''${CONFIG} as:"
              echo '  { "extractor": { "pixiv": { "refresh-token": "<token>" } } }'
            } >&2
          }

          check_auth() {
            if [[ ! -f "''${CONFIG}" ]]; then
              echo "Error: no gallery-dl config at ''${CONFIG}" >&2
              auth_help
              exit 1
            fi

            local TOKEN
            TOKEN="$("''${JQ}" -r '.extractor.pixiv["refresh-token"] // empty' "''${CONFIG}" 2>/dev/null || true)"
            if [[ -z "''${TOKEN}" ]]; then
              echo "Error: ''${CONFIG} has no extractor.pixiv.refresh-token" >&2
              auth_help
              exit 1
            fi
          }

          usage() {
            echo "Usage: pixiv [subfolder] [url]"
            echo ""
            echo "Run without arguments for interactive mode."
            echo ""
            echo "Downloads a pixiv work to ''${BASE_PATH}/<artist>/."
            echo "An animation (ugoira) is converted to GIF; illustrations and manga"
            echo "are saved at original resolution in their source format."
            echo ""
            echo "Examples:"
            echo "  pixiv                                    (interactive)"
            echo "  pixiv https://www.pixiv.net/artworks/123"
            echo "  pixiv refs https://www.pixiv.net/artworks/123"
            exit 1
          }

          download() {
            # Layered on top of ~/.config/gallery-dl/config.json rather than
            # replacing it: -c is additive, so the refresh token stays in the
            # user's own config and is never copied into a temp file or argv.
            local CONF
            CONF="$("''${MKTEMP}" -t pixiv-config.XXXXXXXX.json)"
            trap 'rm -f "''${CONF}"' EXIT

            # Every file carries its zero-padded page index, including
            # single-page works. gallery-dl's `num` is 0-based, so the obvious
            # conditional suffix would silently drop a manga's FIRST page while
            # keeping the rest -- worse than a little noise on singles.
            cat > "''${CONF}" <<EOF
          {
            "extractor": {
              "base-directory": "''${BASE_PATH}",
              "pixiv": {
                "directory": ["{user[name]}"],
                "filename": "{title} - {id}_p{num:>02}.{extension}"
              }
            }
          }
          EOF

            "''${GALLERY_DL}" \
              --config "''${CONF}" \
              --ugoira gif \
              --write-metadata \
              "''${URL}"
          }

          # --- Interactive mode ---
          if [[ $# -eq 0 ]]; then
            check_auth

            if "''${GUM}" confirm "Download to a subfolder?"; then
              SUBFOLDER=$("''${GUM}" input --header "Subfolder name:" --placeholder "e.g. refs")
              if [[ -n "''${SUBFOLDER}" ]]; then
                BASE_PATH="''${BASE_PATH}/''${SUBFOLDER}"
              fi
            fi

            URL=$("''${GUM}" input --header "Artwork URL:" --placeholder "https://www.pixiv.net/artworks/..." --width 80)
            [[ -z "''${URL}" ]] && echo "Error: URL is required" >&2 && exit 1

            echo ""
            "''${GUM}" style --bold --foreground 10 "Downloading to ''${BASE_PATH}"
            echo ""

            download
            exit 0
          fi

          # --- CLI mode ---
          [[ "''${1}" == "-h" || "''${1}" == "--help" ]] && usage

          check_auth

          if [[ $# -ge 2 ]]; then
            SUBFOLDER="''${1}"; shift
            BASE_PATH="''${BASE_PATH}/''${SUBFOLDER}"
          fi

          [[ $# -eq 0 ]] && echo "Error: URL is required" >&2 && usage
          URL="''${1}"

          download
        '';
      };
    };
}
