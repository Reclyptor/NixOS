{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      code-cursor = prev.code-cursor.overrideAttrs (oldAttrs: 
        let
          inherit (prev.stdenv) hostPlatform;
          
          # Define new sources with updated version
          sources = {
            x86_64-linux = prev.fetchurl {
              url = "https://downloads.cursor.com/production/3fa438a81d579067162dd8767025b788454e6f93/linux/x64/Cursor-2.0.38-x86_64.AppImage";
              hash = "sha256-HD+8OytWJrWgMy8PVo2+X7b5UdL6fBQpw7XRH+lvzDA=";
            };
            aarch64-linux = prev.fetchurl {
              url = "https://downloads.cursor.com/production/3fa438a81d579067162dd8767025b788454e6f93/linux/arm64/Cursor-2.0.38-aarch64.AppImage";
              hash = "sha256-YBkSwm7Q/zgd4jrbiF7+GF4kfVru956eG6tcB98eDJ8=";
            };
            x86_64-darwin = prev.fetchurl {
              url = "https://downloads.cursor.com/production/3fa438a81d579067162dd8767025b788454e6f93/darwin/x64/Cursor-darwin-x64.dmg";
              hash = "sha256-MfKkcqiSvYKCcyt8pSnq08NL8lEguk5C6uvDnjwsFNk=";
            };
            aarch64-darwin = prev.fetchurl {
              url = "https://downloads.cursor.com/production/3fa438a81d579067162dd8767025b788454e6f93/darwin/arm64/Cursor-darwin-arm64.dmg";
              hash = "sha256-J4Xx/4ICYO8uKibTX1u5qCk5EHLCcx0wx+taLc4s/QQ=";
            };
          };
          
          source = sources.${hostPlatform.system};
          pname = "cursor";
          version = "2.0.38";
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