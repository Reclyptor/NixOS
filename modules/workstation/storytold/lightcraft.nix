# LightCraft — the Lightroom equivalent: a photo catalog plus a non-destructive
# raw developer.
_: {
  flake.modules.nixos.workstation = import ./_app.nix "lightcraft" (_: {
    version = "0.21.1";
    hash = "sha256-2iqJCmah1bEVCxQ1VeiPWuhuHcR6U6gj6BYYUu4EcsY=";
    cargoHash = "sha256-TU5eFCjfZrpUTn9r/z5EOG5axvVMz5drG8be1GHjTMI=";
    releaseDate = "2026-11-12";
    description = "Photo library and non-destructive raw developer";
    craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";

    # HEIC/HEIF decode, new in 0.6.0 and built by upstream's package.sh. Off by
    # default so distributors choose it, and enabled per package rather than
    # workspace-wide because the gui and cli each gate it separately. Like
    # photocraft's, lightcraft-heif wraps heic-rs, pure Rust, so it costs no
    # native dependency.
    buildFeatures = [
      "lightcraft/heif"
      "lightcraft-cli/heif"
    ];
  });
}
