_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        # A launcher around the stock package rather than an overrideAttrs: one
        # extra flag is not worth rebuilding Element locally when the stock build
        # is in the binary cache. A new launcher rather than wrapProgram, because
        # the stock bin/ already holds a .element-desktop-wrapped of its own.
        element-desktop = prev.symlinkJoin {
          inherit (prev.element-desktop) pname version meta;
          paths = [ prev.element-desktop ];
          nativeBuildInputs = [ prev.makeWrapper ];
          postBuild = ''
            rm $out/bin/element-desktop
            makeWrapper ${prev.element-desktop}/bin/element-desktop $out/bin/element-desktop \
              --add-flags "--password-store=gnome-libsecret"
          '';
        };
      })
    ];
  };
}
