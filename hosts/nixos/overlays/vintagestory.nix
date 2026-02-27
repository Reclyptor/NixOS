{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      vintagestory = prev.stdenv.mkDerivation (finalAttrs: {
        pname = "vintagestory";
        version = "1.21.6";

        src = prev.fetchurl {
          url = "https://cdn.vintagestory.at/gamefiles/stable/vs_client_linux-x64_${finalAttrs.version}.tar.gz";
          hash = "sha256-LkiL/8W9MKpmJxtK+s5JvqhOza0BLap1SsaDvbLYR0c=";
        };

        nativeBuildInputs = with prev; [
          makeWrapper
          copyDesktopItems
        ];

        runtimeLibs = with prev; [
          gtk2
          sqlite
          openal
          cairo
          libGLU
          SDL2
          freealut
          libglvnd
          pipewire
          libpulseaudio
          libx11
          libxi
          libxcursor
        ];

        desktopItems = [
          (prev.makeDesktopItem {
            name = "vintagestory";
            desktopName = "Vintage Story";
            exec = "vintagestory";
            icon = "vintagestory";
            comment = "Innovate and explore in a sandbox world";
            categories = [ "Game" ];
          })
        ];

        installPhase = ''
          runHook preInstall

          mkdir -p $out/share/vintagestory $out/bin $out/share/pixmaps
          cp -r * $out/share/vintagestory
          cp $out/share/vintagestory/assets/gameicon.xpm $out/share/pixmaps/vintagestory.xpm

          runHook postInstall
        '';

        preFixup =
          let
            runtimeLibs' = prev.lib.strings.makeLibraryPath finalAttrs.runtimeLibs;
          in
          ''
            makeWrapper ${prev.lib.meta.getExe prev.dotnet-runtime_8} $out/bin/vintagestory \
              --prefix LD_LIBRARY_PATH : "${runtimeLibs'}" \
              --set-default mesa_glthread true \
              --add-flags $out/share/vintagestory/Vintagestory.dll
            
             find "$out/share/vintagestory/assets/" -not -path "*/fonts/*" -regex ".*/.*[A-Z].*" | while read -r file; do
              local filename="$(basename -- "$file")"
              ln -sf "$filename" "''${file%/*}"/"''${filename,,}"
            done
          '';

        meta = with prev.lib; {
          description = "In-development indie sandbox game about innovation and exploration";
          homepage = "https://www.vintagestory.at/";
          license = licenses.unfree;
          sourceProvenance = [ sourceTypes.binaryBytecode ];
          platforms = platforms.linux;
        };
      });
    })
  ];
}
