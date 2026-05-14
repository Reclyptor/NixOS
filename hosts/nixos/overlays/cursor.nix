{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      code-cursor = prev.code-cursor.overrideAttrs (oldAttrs: 
        let
          inherit (prev.stdenv) hostPlatform;
          
          # Define new sources with updated version
          sources = {
            x86_64-linux = prev.fetchurl {
              url = "https://downloads.cursor.com/production/93e603f703cd553a6bb3644711a3379bbbb3118f/linux/x64/Cursor-3.4.17-x86_64.AppImage";
              hash = "sha256-ZMmvIZQdGkDBFiOlCszYrvaF6EgNyiqWgp/Q67MY6Ww=";
            };
          };

          source = sources.${hostPlatform.system};
          pname = "cursor";
          version = "3.4.17";
        in {
          # Override version and src with proper AppImage extraction
          inherit version;
          src = if hostPlatform.isLinux then
            prev.appimageTools.extract {
              inherit pname version;
              src = source;
            }
          else
            source;
          
          # Override sourceRoot to match new version
          sourceRoot = if hostPlatform.isLinux 
            then "${pname}-${version}-extracted/usr/share/cursor"
            else "Cursor.app";
          
          # cursor-agent-exec ships a musl-compiled node module
          buildInputs = oldAttrs.buildInputs ++ [ prev.musl ];

          # Update passthru to include new sources
          passthru = oldAttrs.passthru // {
            inherit sources;
          };
        }
      );
    })
  ];
}
