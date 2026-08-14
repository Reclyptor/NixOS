{ config, ... }:

# Stable /dev symlinks for USB optical drives, generated from typed data instead
# of hand-written udev blobs.
#
# The old arrangement kept three separate hand-maintained rule blocks — a
# workstation copy, a "fleet standard" default applied to four cluster nodes, and
# styxeon's override. All three listed overlapping serials, so four nodes carried
# rules for drives that were physically plugged into a different machine. The
# real inventory is 8 drives on styxeon and 1 on the workstation; every other
# node has none, verified against /dev/sr* on each host.
let
  # Captured out here because `config` is shadowed by the NixOS one inside `mod`.
  # Same submodule type the fleet inventory uses, so a drive is described the
  # same way whether it hangs off a cluster node or the workstation.
  driveType = config.fleet.opticalDriveType;

  mod =
    { config, lib, ... }:
    let
      drives = config.opticalDrives;

      # Block device (sr) -> /dev/<name>. USB enumeration order is not stable,
      # the serial is — which is the whole point of matching on it.
      blockRule = d: ''SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="${d.serial}", SYMLINK+="${d.name}"'';

      # SCSI-generic (sg) -> /dev/<name>-sg, needed by tools that drive the disc
      # through the sg interface. ATTRS{} walks ancestors; the USB device is what
      # holds the serial attribute.
      sgRule = d: ''SUBSYSTEM=="scsi_generic", ATTRS{serial}=="${d.serial}", SYMLINK+="${d.name}-sg"'';

      sgDrives = lib.filter (d: d.sg) drives;

      rules =
        "# Generated from opticalDrives — edit the inventory, not this.\n"
        + lib.concatMapStringsSep "\n" blockRule drives
        + "\n"
        + lib.optionalString (sgDrives != [ ]) ("\n" + lib.concatMapStringsSep "\n" sgRule sgDrives + "\n");
    in
    {
      options.opticalDrives = lib.mkOption {
        type = lib.types.listOf driveType;
        default = [ ];
        description = "Optical drives attached to this machine; udev rules are generated from these.";
      };

      config.services.udev.extraRules = lib.mkIf (drives != [ ]) rules;
    };
in
{
  flake.modules.nixos.server = mod;
  flake.modules.nixos.workstation = mod;
}
