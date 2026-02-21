{ config, pkgs, ... }:
let driver = config.boot.kernelPackages.nvidiaPackages.stable; in {
  nixpkgs.config.nvidia.acceptLicense = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  environment.sessionVariables = {
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
    CUDA_HOME = "${pkgs.cudaPackages.cudatoolkit}";
    LD_LIBRARY_PATH = "$LD_LIBRARY_PATH:${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib";
    EXTRA_LDFLAGS = "-L${pkgs.cudaPackages.cudatoolkit}/lib -L${pkgs.cudaPackages.cudnn}/lib";
    EXTRA_CCFLAGS = "-I${pkgs.cudaPackages.cudatoolkit}/include -I${pkgs.cudaPackages.cudnn}/include";
  };

  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
  ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      package = driver;
    };

    nvidia = {
      open = false;
      nvidiaSettings = false;
      modesetting.enable = true;
      package = driver;
      powerManagement = {
        enable = false;
        finegrained = false;
      };
    };

    nvidia-container-toolkit.enable = true;
  };
}
