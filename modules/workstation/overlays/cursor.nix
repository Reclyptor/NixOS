_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        code-cursor = prev.code-cursor.overrideAttrs (
          oldAttrs:
          let
            inherit (prev.stdenv) hostPlatform;

            # Define new sources with updated version
            sources = {
              x86_64-linux = prev.fetchurl {
                url = "https://downloads.cursor.com/production/306d153d51d714882ab7b1bc49649cab624e8a31/linux/x64/Cursor-3.29.9-x86_64.AppImage";
                hash = "sha256-xDtVthf031Xgmgv9fj54IJxuwQuCFcgupePxn11MppM=";
              };
            };

            source = sources.${hostPlatform.system};
            pname = "cursor";
            version = "3.29.9";
          in
          {
            # Override version and src with proper AppImage extraction
            inherit version;
            src =
              if hostPlatform.isLinux then
                prev.appimageTools.extract {
                  inherit pname version;
                  src = source;
                }
              else
                source;

            # Override sourceRoot to match new version
            sourceRoot =
              if hostPlatform.isLinux then "${pname}-${version}-extracted/usr/share/cursor" else "Cursor.app";

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
  };
}
