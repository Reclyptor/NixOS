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
                url = "https://downloads.cursor.com/production/2d29876d567da1607532b23bbf2cd5ddbca496fe/linux/x64/Cursor-3.23.12-x86_64.AppImage";
                hash = "sha256-a6Cwao6Qh2iPMSuEhOYc4owYW2CcNzG4kG4XpqqYojg=";
              };
            };

            source = sources.${hostPlatform.system};
            pname = "cursor";
            version = "3.23.12";
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
