{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      code-cursor = prev.code-cursor.overrideAttrs (oldAttrs: 
        let
          inherit (prev.stdenv) hostPlatform;
          
          # Define new sources with updated version
          sources = {
            x86_64-linux = prev.fetchurl {
              url = "https://downloads.cursor.com/production/e7a7e93f4d75f8272503ecf33cedbaae10114a15/linux/x64/Cursor-3.6.21-x86_64.AppImage";
              hash = "sha256-6zIhSz5fxEMLA8zd6oZtwNDUMAW65bZu/fYMSV/Iuh0=";
            };
          };

          source = sources.${hostPlatform.system};
          pname = "cursor";
          version = "3.6.21";
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
