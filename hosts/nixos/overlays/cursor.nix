{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      code-cursor = prev.code-cursor.overrideAttrs (oldAttrs: 
        let
          inherit (prev.stdenv) hostPlatform;
          
          # Define new sources with updated version
          sources = {
            x86_64-linux = prev.fetchurl {
              url = "https://downloads.cursor.com/production/009bb5a3600dd98fe1c1f25798f767f686e14759/linux/x64/Cursor-3.5.38-x86_64.AppImage";
              hash = "sha256-xtM0m1KJld1RfMxbMxG4GadODNh2Uzww11c+AaQibc8=";
            };
          };

          source = sources.${hostPlatform.system};
          pname = "cursor";
          version = "3.5.38";
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
