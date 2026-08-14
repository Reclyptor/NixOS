_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      libreoffice-fresh
      hunspell
      hunspellDicts.en_US
    ];
  };
}
