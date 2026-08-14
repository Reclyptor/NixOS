_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        element-desktop = prev.element-desktop.overrideAttrs (oldAttrs: {
          postFixup = (oldAttrs.postFixup or "") + ''
            wrapProgram $out/bin/element-desktop \
              --add-flags "--password-store=gnome-libsecret"
          '';
        });
      })
    ];
  };
}
