{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    libreoffice-fresh
    hunspell
    hunspellDicts.en_US
  ];
}
