{ inputs, ... }:
{
  # gpu-unlock (https://github.com/Zagitta/gpu-unlock) has to reach a card
  # before nvidia binds it; loading it afterwards does nothing. The initrd
  # gives that order for free: nvidia is only ever loaded from the root
  # filesystem here (base.nix), so a module loaded in the initrd is always
  # first, with no softdep or udev rule to keep in step with the driver's own.
  flake.modules.nixos.server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      src = inputs.gpu-unlock;
    in
    lib.mkIf config.host.gpuUnlock {
      assertions = [
        {
          assertion = config.host.gpu == "nvidia";
          message = "host.gpuUnlock needs host.gpu = \"nvidia\".";
        }
        {
          assertion = !lib.elem "nvidia" config.boot.initrd.kernelModules;
          message = "gpu-unlock relies on nvidia loading after the initrd; with nvidia in boot.initrd.kernelModules the two would race for the card.";
        }
      ];

      boot.extraModulePackages = [
        (config.boot.kernelPackages.callPackage ./_gpu-unlock/module.nix { inherit src; })
      ];
      hardware.firmware = [ (pkgs.callPackage ./_gpu-unlock/firmware.nix { inherit src; }) ];

      boot.initrd.kernelModules = [ "gpu_unlock" ];
      # The module is inert without this.
      boot.kernelParams = [ "gpu_unlock.targets=all" ];

      # The GSP image does not compress, so it takes the initrd from 43 MiB
      # to 111 MiB, about 125 MiB a generation with its kernel. A switch
      # writes the new generation before it prunes, so the ESP briefly holds
      # one more than the limit: seven fit bytheon's 1022 MiB ESP, eleven
      # would not.
      boot.loader.systemd-boot.configurationLimit = 6;
    };
}
