# DesignCraft — the InDesign equivalent. Reads IDML, writes PDF and EPUB.
_: {
  flake.modules.nixos.workstation = import ./_app.nix "designcraft" (_: {
    version = "0.20.1";
    hash = "sha256-rsQfF66CymQ46Ty+RG76A46d6mD8HcMHCOH9EE6sog4=";
    cargoHash = "sha256-BmlQ/G1pBW34W13sTz8jPi/kbzrtB5ZcTyrNOXgpidE=";
    releaseDate = "2026-11-12";
    description = "Page layout for magazines, books and print documents";
    craftFontsRev = "b076417b5880bd4154bd22f00695b1d28c6bea83";

    # File-manager thumbnails, new in upstream's package.sh. The entry runs
    # `designcraft-cli thumbnail` from PATH.
    extraPostInstall = ''
      install -Dm644 packaging/linux/ai.storyteller.designcraft.thumbnailer \
        -t $out/share/thumbnailers
    '';
  });
}
