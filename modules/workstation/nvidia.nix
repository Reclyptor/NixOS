_: {
  flake.modules.nixos.workstation = { config, ... }: {
    nixpkgs.config.nvidia.acceptLicense = true;

    services.xserver.videoDrivers = [ "nvidia" ];

    # Load NVIDIA modules early for stable KMS bring-up.
    boot.initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
    boot.blacklistedKernelModules = [ "nouveau" ];
    boot.kernelParams = [
      "module_blacklist=nouveau"
      "modprobe.blacklist=nouveau"
      "rd.driver.blacklist=nouveau"
    ];

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };

      nvidia = {
        open = true; # Required for Blackwell (RTX 50xx)
        modesetting.enable = true;
        nvidiaSettings = true;
        # nixpkgs' own production channel rather than a hand-pinned mkDriver
        # block. This used to carry 595.71.05 with six pasted hashes, from when
        # nixpkgs trailed what Blackwell needed; it has since overtaken that pin,
        # so the hashes were pure maintenance debt — every bump meant fetching
        # five tarballs by hand and getting them right.
        #
        # 595.99.02 is also the floor for two things that matter here. DXVK 3.0
        # uses VK_EXT_descriptor_heap by default but only on NVIDIA >= 595.84,
        # and that extension is the fix for the descriptor penalty that made DX12
        # under vkd3d-proton slower than DX11 on NVIDIA — which is exactly the
        # path WoW runs on. 595.71.05 sat below that line and forfeited it.
        #
        # It also moves off the version named in open-gpu-kernel-modules#1151,
        # which reports random unrecoverable Xid 79 on GB203 at 595.71.05 with
        # the open module specifically. That is one reporter with no NVIDIA
        # acknowledgement, so it is not the reason for this change so much as a
        # second thing the change happens to address. `open` stays true: this is
        # Blackwell, and nothing in that report distinguishes the driver version
        # from the module choice well enough to justify flipping both at once.
        package = config.boot.kernelPackages.nvidiaPackages.production;
        powerManagement.enable = false;
        powerManagement.finegrained = false;
      };
    };
  };
}
