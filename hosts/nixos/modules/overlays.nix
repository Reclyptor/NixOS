{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      code-cursor = prev.code-cursor.overrideAttrs (oldAttrs: 
        let
          inherit (prev.stdenv) hostPlatform;
          
          # Define new sources with updated version
          sources = {
            x86_64-linux = prev.fetchurl {
	      url = "https://downloads.cursor.com/production/2ca326e0d1ce10956aea33d54c0e2d8c13c58a32/linux/x64/Cursor-2.3.41-x86_64.AppImage";
	      hash = "sha256-ItUgknMzSDeXxN3Yi/pz2wZoz7vVVqx9nGXuGmbHbXc=";
            };
          };
          
          source = sources.${hostPlatform.system};
          pname = "cursor";
          version = "2.3.41";
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
