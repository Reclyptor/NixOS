{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    git
    kubectl
    neovim
    openiscsi
    wget
    pciutils
    libva-utils
    nvtopPackages.nvidia
    nvidia-vaapi-driver
    mesa-demos
    ffmpeg-full
  ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
