# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" "sg" ];
  boot.extraModulePackages = [ ];
  boot.blacklistedKernelModules = [ "hid_playstation" ];
  boot.extraModprobeConfig = ''
    install hid_playstation /bin/false
  '';

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/16a5ec29-306a-46d0-af93-9d2e9149e99a";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/1C46-571F";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices = [ ];

  fileSystems."/data/nvme/ssd-4tb" = {
    device = "/dev/disk/by-uuid/7970db63-f32c-42cc-aeba-8838c3fcabbc";
    fsType = "ext4";
    options = [ "defaults" ];
  };

  fileSystems."/data/nvme/ssd-2tb" = {
    device = "/dev/disk/by-uuid/91613b5f-5174-46c9-9644-e9b027eb5e67";
    fsType = "ext4";
    options = [ "defaults" ];
  };

  fileSystems."/data/nfs/truenas/videos" = {
    device = "192.168.1.2:/mnt/primary/videos";
    fsType = "nfs4";
    options = [ "defaults" "_netdev" "x-systemd.automount" ];
  };

  fileSystems."/data/nfs/flashstor/videos" = {
    device = "192.168.1.3:/mnt/primary/videos";
    fsType = "nfs4";
    options = [ "defaults" "_netdev" "x-systemd.automount" ];
  };

  fileSystems."/data/nfs/asustor/videos" = {
    device = "192.168.1.4:/volume1/Videos";
    fsType = "nfs4";
    options = [ "defaults" "_netdev" "x-systemd.automount" ];
  };

  fileSystems."/data/nfs/asustor/archive" = {
    device = "192.168.1.4:/volume1/Archive";
    fsType = "nfs4";
    options = [ "defaults" "_netdev" "x-systemd.automount" ];
  };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno2.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp6s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
