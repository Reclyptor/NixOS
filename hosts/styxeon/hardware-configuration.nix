# PLACEHOLDER - Replace with output from 'nixos-generate-config' on darkeon
# Run: sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # TODO: Update filesystem UUIDs from actual hardware
  # fileSystems."/" =
  #   { device = "/dev/disk/by-uuid/XXXX";
  #     fsType = "ext4";
  #   };

  # fileSystems."/boot" =
  #   { device = "/dev/disk/by-uuid/XXXX";
  #     fsType = "vfat";
  #     options = [ "fmask=0077" "dmask=0077" ];
  #   };

  # swapDevices =
  #   [ { device = "/dev/disk/by-uuid/XXXX"; }
  #   ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
