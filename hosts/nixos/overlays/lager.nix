{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      lager = prev.lager.overrideAttrs (oldAttrs: {
        # Boost 1.89 removed the boost_system stub library (header-only since 1.69)
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace CMakeLists.txt \
            --replace-fail "find_package(Boost 1.56 COMPONENTS system REQUIRED)" \
                           "find_package(Boost 1.56 REQUIRED)"
        '';
      });
    })
  ];
}
