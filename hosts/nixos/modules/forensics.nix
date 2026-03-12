{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # metadata
    exiftool     # read/inspect EXIF, XMP, and other metadata
    mat2         # strip all metadata from files before sharing

    # steganography
    steghide     # hide/extract data in image and audio files
    stegseek     # fast steghide passphrase bruteforcer
    zsteg        # PNG/BMP steg detection
    imagemagick  # image manipulation and analysis

    # binary analysis / reverse engineering
    binwalk      # firmware/binary analysis and extraction
    foremost     # file carving / data recovery
    ghidra       # NSA reverse engineering suite
    radare2      # command-line RE framework
    gdb          # debugger
    gef          # GDB enhanced features for exploit dev
    ropgadget    # ROP gadget finder
    checksec     # check binary protections (NX, PIE, canary, RELRO)
    strace       # syscall tracing
    ltrace       # library call tracing

    # pwn / exploitation
    pwntools     # CTF exploitation framework

    # cryptography / password cracking
    hashcat      # GPU-accelerated hash cracking
    john         # CPU hash cracking (john the ripper)
    sage         # math toolkit for crypto/number theory challenges

    # web
    sqlmap       # SQL injection automation
    feroxbuster  # fast directory/file brute forcing
    burpsuite    # web proxy and interceptor

    # network / packet analysis
    wireshark    # packet capture and analysis
    socat        # multipurpose relay (essential for CTF pwn)
    tcpdump      # lightweight packet capture

    # disk / memory forensics
    sleuthkit    # disk image forensics toolkit
    testdisk     # partition recovery and file carving
    volatility3  # memory forensics framework

    # misc
    imhex        # hex editor with pattern language
    cyberchef    # data transformation and encoding swiss army knife
  ];
}
