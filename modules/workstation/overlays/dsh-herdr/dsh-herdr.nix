_: {
  flake.modules.nixos.workstation =
    { lib, ... }:
    {
      nixpkgs.overlays = [
        (final: _prev: {
          # A cordis bundle layer for the dsh tui profile: it watches the
          # harness's own session/event stream and tells herdr which dsh
          # conversation the pane is holding — the one thing herdr cannot read
          # off the screen. State stays with herdr's screen manifest on purpose
          # (see the plugin's own header).
          #
          # Consumed through deepseek.profiles.<name>.plugins, so packageName
          # and packageRoot are the contract home/deepseek/deepseek.nix expects.
          # `_runtime` is `_`-prefixed so import-tree skips it: the JS beside
          # this file is data, not a flake-parts module.
          dsh-herdr =
            let
              self =
                final.runCommandLocal "dsh-herdr-0.1.0"
                  {
                    passthru = {
                      packageName = "@reclyptor/dsh-herdr";
                      packageRoot = self;
                    };

                    meta = {
                      description = "Reports dsh session identity to herdr so conversations survive a server restart";
                      platforms = lib.platforms.all;
                    };
                  }
                  ''
                    mkdir -p $out
                    cp -r ${./_runtime}/. $out/
                  '';
            in
            self;
        })
      ];
    };
}
