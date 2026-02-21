{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    git
    kubectl
    neovim
    openiscsi
    wget
    pciutils
    libva-utils
    vulkan-tools
    clinfo
    ffmpeg-full
    radeontop
    mesa-demos
  ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
