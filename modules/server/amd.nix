_: {
  flake.modules.nixos.server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf (config.host.gpu == "amd") {
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          mesa
          libva-vdpau-driver
          libvdpau-va-gl
          rocmPackages.clr.icd
        ];
        extraPackages32 = with pkgs.pkgsi686Linux; [
          mesa
          libva-vdpau-driver
          libvdpau-va-gl
        ];
      };

      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "radeonsi";
        AMD_VULKAN_ICD = "RADV";
        RADV_PERFTEST = "gpl";
      };

      # Plex hardware transcode (VAAPI via /dev/dri). Lived in server/iscsi.nix
      # for years; it is AMD-node configuration, so it belongs beside the
      # driver setup the condition already gates.
      systemd.tmpfiles.rules = [
        "d /dev/dri 0755 root video -"
        "d /var/lib/plex-transcode 0755 root root -"
      ];
    };
}
