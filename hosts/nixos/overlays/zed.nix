{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      zed-editor = prev.zed-editor.overrideAttrs (oldAttrs: {
        version = "0.226.4";

        src = prev.fetchFromGitHub {
          owner = "zed-industries";
          repo = "zed";
          tag = "v0.226.4";
          hash = "sha256-vF/vvEJKl1mUcF6TMif5G9rQPjt+2RWImWy1f7RxgfE=";
        };

        cargoDeps = prev.rustPlatform.fetchCargoVendor {
          src = prev.fetchFromGitHub {
            owner = "zed-industries";
            repo = "zed";
            tag = "v0.226.4";
            hash = "sha256-vF/vvEJKl1mUcF6TMif5G9rQPjt+2RWImWy1f7RxgfE=";
          };
          postBuild = ''
            rm -r $out/git/*/candle-book/
          '';
          hash = "sha256-IH/FEC52VudtXsSHiju6T7H9E2kblJ0RyiUoQR391cc=";
        };
      });
    })
  ];
}
