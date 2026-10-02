_:

# Timezone, locale, and keyboard layout, defined once. This block was
# duplicated verbatim between server/base.nix and workstation/locale.nix —
# same timezone, same defaultLocale, all nine extraLocaleSettings identical.
let
  locale = _: {
    time.timeZone = "America/Chicago";

    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };

    services.xserver.xkb.layout = "us";
  };
in
{
  flake.modules.nixos.server = locale;

  flake.modules.nixos.workstation = _: {
    imports = [ locale ];

    # ja_JP on the workstation only, because only the workstation runs Japanese
    # games. Doujin and visual-novel titles from DLsite and itch.io are routinely
    # built against Shift-JIS and ask the OS for a Japanese locale; without one
    # generated, Wine hands them the C locale and every string renders as
    # mojibake (文字化け) — the same problem Locale Emulator exists to solve on
    # Windows. Fonts were never the issue here: fonts.nix already installs
    # noto-fonts-cjk-sans and pins the JP face so fontconfig cannot draw Japanese
    # with Korean glyph forms. The locale simply was not generated.
    #
    # Spelled out in full rather than appended, because the option's default is
    # computed from defaultLocale plus extraLocaleSettings and a definition
    # REPLACES that default rather than extending it. The two entries below are
    # exactly what the default evaluated to before this was added, so this is
    # purely additive — verified with `nix eval` on both this host and a server.
    #
    # Games still need LANG/LC_ALL pointed at it per-prefix; generating the
    # locale is the half that has to exist system-wide.
    i18n.supportedLocales = [
      "C.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
      "ja_JP.UTF-8/UTF-8"
    ];
  };
}
