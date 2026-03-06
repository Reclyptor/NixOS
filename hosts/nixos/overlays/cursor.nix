{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      code-cursor = prev.code-cursor.overrideAttrs (oldAttrs: 
        let
          inherit (prev.stdenv) hostPlatform;
          
          # Define new sources with updated version
          sources = {
            x86_64-linux = prev.fetchurl {
              url = "https://downloads.cursor.com/production/1917e900a0c4b0111dc7975777cfff60853059d3/linux/x64/Cursor-2.6.12-x86_64.AppImage";
              hash = "sha256-R/s8CMJjo8RLRCSVeNmldCI39D+6VkWc1/Enql5W6Zo=";
            };
          };
          
          source = sources.${hostPlatform.system};
          pname = "cursor";
          version = "2.6.12";
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
          
          # Update passthru to include new sources
          passthru = oldAttrs.passthru // {
            inherit sources;
          };
        }
      );
    })
  ];
}
