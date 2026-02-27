{ pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      openrgb = prev.openrgb.overrideAttrs (old: {
        version = "git";
        src = prev.fetchFromGitLab {
          owner = "CalcProgrammer1";
          repo = "OpenRGB";
          rev = "master";
          hash = "sha256-vOYaiWw0wjCf76OjWXZ5o7lVqL7dhxpdah8bGFBrZm0=";
        };
        patches = [ ];
        postPatch = ''
          patchShebangs scripts/build-udev-rules.sh
        '';
        postInstall = (old.postInstall or "") + ''
          if [ -f "$out/lib/udev/rules.d/60-openrgb.rules" ]; then
            substituteInPlace "$out/lib/udev/rules.d/60-openrgb.rules" \
              --replace-fail "/usr/bin/env chmod" "${prev.coreutils}/bin/chmod"
          fi
        '';
      });
    })
  ];
}
