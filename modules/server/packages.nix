_: {
  flake.modules.nixos.server = { config, pkgs, ... }: {
    environment.systemPackages =
      with pkgs;
      [
        git
        kubectl
        rcon-cli
        neovim
        openiscsi
        wget
        pciutils
        libva-utils
      ]
      ++ (
        if config.host.gpu == "amd" then
          [
            vulkan-tools
            clinfo
            ffmpeg-full
            radeontop
            mesa-demos
          ]
        else
          [
            nvtopPackages.nvidia
            nvidia-vaapi-driver
            mesa-demos
            ffmpeg-full
          ]
      );

    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };
}
