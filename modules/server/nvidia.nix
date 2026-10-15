_: {
  flake.modules.nixos.server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      driver = config.boot.kernelPackages.nvidiaPackages.stable;
      nctk = config.hardware.nvidia-container-toolkit.package;
    in
    lib.mkIf (config.host.gpu == "nvidia") {
      nixpkgs.config.nvidia.acceptLicense = true;

      systemd.services.nvidia-power-limit = lib.mkIf (config.host.gpuPowerLimit != null) {
        description = "Cap every NVIDIA GPU at ${toString config.host.gpuPowerLimit} W";
        wantedBy = [ "multi-user.target" ];
        after = [ "nvidia-persistenced.service" ];
        requires = [ "nvidia-persistenced.service" ];
        before = [ "k3s.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${lib.getExe' driver.bin "nvidia-smi"} --power-limit ${toString config.host.gpuPowerLimit}";
        };
      };

      services.xserver.videoDrivers = [ "nvidia" ];

      environment.sessionVariables = {
        CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
        CUDA_HOME = "${pkgs.cudaPackages.cudatoolkit}";
        LD_LIBRARY_PATH = "$LD_LIBRARY_PATH:${driver}/lib:${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib";
        EXTRA_LDFLAGS = "-L${pkgs.cudaPackages.cudatoolkit}/lib -L${pkgs.cudaPackages.cudnn}/lib";
        EXTRA_CCFLAGS = "-I${pkgs.cudaPackages.cudatoolkit}/include -I${pkgs.cudaPackages.cudnn}/include";
      };

      environment.systemPackages = with pkgs; [
        cudaPackages.cudatoolkit
        cudaPackages.cudnn
        nvidia-container-toolkit
        nvidia-container-toolkit.tools
      ];

      environment.etc."nvidia-container-runtime/config.toml".text = ''
        disable-require = true
        supported-driver-capabilities = "compat32,compute,display,graphics,ngx,utility,video"
        [nvidia-container-cli]
        environment = []
        ldconfig = "@${lib.getExe' pkgs.glibc "ldconfig"}"
        load-kmods = true
        no-cgroups = false
        path = "${lib.getExe' pkgs.libnvidia-container "nvidia-container-cli"}"
        [nvidia-container-runtime]
        mode = "cdi"
        runtimes = ["runc", "crun"]
        [nvidia-container-runtime-hook]
        path = "${lib.getOutput "tools" nctk}/bin/nvidia-container-runtime-hook"
        skip-mode-detection = false
        [nvidia-ctk]
        path = "${lib.getExe' nctk "nvidia-ctk"}"
      '';

      hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
        };

        nvidia = {
          open = false;
          nvidiaSettings = false;
          modesetting.enable = true;
          package = driver;
          # Keeps the driver initialized between CUDA clients, so a power
          # limit set at boot holds.
          nvidiaPersistenced = config.host.gpuPowerLimit != null;
        };

        nvidia-container-toolkit = {
          enable = true;
          device-name-strategy = "uuid";
        };
      };
    };
}
