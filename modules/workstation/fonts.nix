_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    fonts.packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      noto-fonts-cjk-sans
      atkinson-hyperlegible
      # The 2025 revision, carrying a variable weight axis. The dsh web skin
      # asks for 400/500/600/700 and the 2021 cut above ships only 400 and 700,
      # which leaves the browser synthesizing the two middle weights.
      atkinson-hyperlegible-next
      open-dyslexic
    ];
  };
}
