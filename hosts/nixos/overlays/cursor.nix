{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      code-cursor = prev.code-cursor.overrideAttrs (oldAttrs: 
        let
          inherit (prev.stdenv) hostPlatform;
          
          # Define new sources with updated version
          sources = {
            x86_64-linux = prev.fetchurl {
              url = "https://downloads.cursor.com/production/a80ff7dfcaa45d7750f6e30be457261379c29b06/linux/x64/Cursor-3.0.12-x86_64.AppImage";
              hash = "sha256-SdlcESipjWnLNPGf4sBxb28cpQ36uHoRzGsPC9X72Ww=";
            };
          };
          
          source = sources.${hostPlatform.system};
          pname = "cursor";
          version = "3.0.12";
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
