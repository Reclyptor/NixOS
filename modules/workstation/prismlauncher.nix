_: {
  # Prism Launcher (github.com/PrismLauncher/PrismLauncher) — the Minecraft
  # launcher.
  #
  # Prism records the Java it picks as an absolute path in each instance.cfg.
  # nixpkgs' wrapper advertises its JDKs as /nix/store paths, so after a flake
  # update every instance keeps launching the previous generation's JDK on that
  # generation's glibc, which can't load the current graphics drivers (and the
  # instance stops launching once that generation is collected). Instead the
  # wrapper advertises fixed paths under /run/current-system/sw that each rebuild
  # retargets at the current JDKs. Prism uses PRISMLAUNCHER_JAVA_PATHS entries
  # verbatim, so these stable paths are what gets written into instance.cfg.
  flake.modules.nixos.workstation =
    { pkgs, ... }:
    let
      # nixpkgs' default set for prismlauncher, newest first.
      jdks = [
        "jdk25"
        "jdk21"
        "jdk17"
        "jdk8"
      ];
      jdksDir = "share/prismlauncher/jdks";
    in
    {
      environment.pathsToLink = [ "/share/prismlauncher" ];

      environment.systemPackages = [
        (pkgs.linkFarm "prismlauncher-jdks" (
          map (name: {
            name = "${jdksDir}/${name}";
            path = pkgs.${name};
          }) jdks
        ))

        (
          (pkgs.prismlauncher.override {
            jdks = map (name: "/run/current-system/sw/${jdksDir}/${name}") jdks;
          }).overrideAttrs
            (previous: {
              # NVIDIA's threaded GL optimizations break Minecraft 26.x's OpenGL
              # backend: SDL3 creates a second hidden GL window after the first
              # context is current, and its eglChooseConfig fails with
              # EGL_BAD_DISPLAY. Minecraft then falls back to Vulkan, which Iris
              # can't run on. Sodium tries to disable this at runtime, but by then
              # the driver has already read it. Prism passes __GL_* through to the
              # game, and only the NVIDIA driver reads it.
              qtWrapperArgs = previous.qtWrapperArgs ++ [ "--set __GL_THREADED_OPTIMIZATIONS 0" ];
            })
        )
      ];
    };
}
