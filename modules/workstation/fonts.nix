{ ... }: {
  flake.modules.nixos.workstation = { config, pkgs, ... }: {
    fonts.packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      noto-fonts-cjk-sans
      atkinson-hyperlegible
      open-dyslexic
    ];
  };
}
