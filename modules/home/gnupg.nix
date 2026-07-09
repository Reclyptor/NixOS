{ ... }: {
  flake.modules.homeManager.base = { ... }: {
    # scdaemon's built-in CCID driver claims the YubiKey's USB interface
    # exclusively via libusb, which knocks the reader out of pcscd and starves
    # every PC/SC client (age-plugin-yubikey, ykman, opensc). disable-ccid
    # makes it go through pcscd in shared mode instead.
    home.file.".gnupg/scdaemon.conf".text = ''
      disable-ccid
    '';
  };
}
