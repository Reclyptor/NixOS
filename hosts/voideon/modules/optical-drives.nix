{ config, pkgs, ... }: {
  services.udev.extraRules = ''
    # Stable symlinks for optical drives based on serial numbers
    # These won't change even if USB enumeration order changes
    
    SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="BP52D24A16083824", SYMLINK+="bluray0"
    SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="BP52524422173906", SYMLINK+="bluray1"
    SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="BP52E25510161815", SYMLINK+="bluray2"
    SUBSYSTEM=="block", ENV{ID_SERIAL_SHORT}=="BP52E25512093803", SYMLINK+="bluray3"
  '';
}

