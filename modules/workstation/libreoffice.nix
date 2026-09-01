_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      libreoffice-stable
      hunspell
      hunspellDicts.en_US
    ];
  };
}
