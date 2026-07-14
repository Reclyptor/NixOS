{ config, ... }: {
  configurations.nixos.styxeon = {
    imports = [
      ../../hardware/styxeon.nix
      config.flake.modules.nixos.server
    ];

    host = {
      hostId = "cc1aa076";
      wiredIp = "192.168.1.13";
      wirelessIp = "192.168.1.23";
      k3s.role = "agent";

      # This node runs the rippers: more drives than the fleet default, and the
      # newer bluray-<serial> naming plus SCSI-generic (sg) symlinks.
      opticalDriveRules = ''
        # Stable symlinks for optical drives by USB serial.
        # Block device (sr) -> /dev/bluray-<serial>
        SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="BP52225B18130019", SYMLINK+="bluray-BP52225B18130019"
        SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="BP52225B18133253", SYMLINK+="bluray-BP52225B18133253"
        SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="BP52225C07131304", SYMLINK+="bluray-BP52225C07131304"
        SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="BP52425B18130826", SYMLINK+="bluray-BP52425B18130826"
        SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="BP52524422173906", SYMLINK+="bluray-BP52524422173906"
        SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="BP52D24A16083824", SYMLINK+="bluray-BP52D24A16083824"
        SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="BP52E25510161815", SYMLINK+="bluray-BP52E25510161815"
        SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="BP52E25512093803", SYMLINK+="bluray-BP52E25512093803"

        # SCSI-generic (sg) -> /dev/bluray-<serial>-sg
        # ATTRS{} walks ancestors; the USB device holds the serial attribute.
        SUBSYSTEM=="scsi_generic", ATTRS{serial}=="BP52225B18130019", SYMLINK+="bluray-BP52225B18130019-sg"
        SUBSYSTEM=="scsi_generic", ATTRS{serial}=="BP52225B18133253", SYMLINK+="bluray-BP52225B18133253-sg"
        SUBSYSTEM=="scsi_generic", ATTRS{serial}=="BP52225C07131304", SYMLINK+="bluray-BP52225C07131304-sg"
        SUBSYSTEM=="scsi_generic", ATTRS{serial}=="BP52425B18130826", SYMLINK+="bluray-BP52425B18130826-sg"
        SUBSYSTEM=="scsi_generic", ATTRS{serial}=="BP52524422173906", SYMLINK+="bluray-BP52524422173906-sg"
        SUBSYSTEM=="scsi_generic", ATTRS{serial}=="BP52D24A16083824", SYMLINK+="bluray-BP52D24A16083824-sg"
        SUBSYSTEM=="scsi_generic", ATTRS{serial}=="BP52E25510161815", SYMLINK+="bluray-BP52E25510161815-sg"
        SUBSYSTEM=="scsi_generic", ATTRS{serial}=="BP52E25512093803", SYMLINK+="bluray-BP52E25512093803-sg"
      '';
    };
  };
}
