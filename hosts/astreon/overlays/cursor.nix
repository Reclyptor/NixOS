{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      code-cursor = prev.code-cursor.overrideAttrs (oldAttrs: 
        let
          inherit (prev.stdenv) hostPlatform;
          
          # Define new sources with updated version
          sources = {
            x86_64-linux = prev.fetchurl {
              url = "https://downloads.cursor.com/production/f3f5cec40024283013878b50c4f9be4002e0b587/linux/x64/Cursor-2.4.28-x86_64.AppImage";
              hash = "sha256-Vkat7mTge3yDDzWAfwuapuwsUCPBrl41THA1WEAvTyY=";
            };
          };
          
          source = sources.${hostPlatform.system};
          pname = "cursor";
          version = "2.4.28";
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
