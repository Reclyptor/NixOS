_: {
  # Ledger Live, the companion app for Ledger hardware wallets. Trojanized
  # Ledger Live builds are a common way to drain wallets, so this pins the
  # exact bytes Ledger signed rather than trusting whatever a mirror serves.
  #
  # nixpkgs lags upstream, and its recipe keeps the version in a let-binding
  # overrideAttrs can't reach (the extracted desktop file and icon would still
  # come from the old AppImage), so the recipe is restated here at our version.
  #
  # The hash below is NOT trust-on-first-use: it is the SHA-512 Ledger
  # publishes in its ECDSA-signed checksum file, base64-encoded into SRI form.
  # fetchurl rejects any download that doesn't match it byte for byte.
  #
  # To bump (never take the hash from a failed build's "got:" line):
  #   V=<new version>; B=https://resources.live.ledger.app/public_resources/signatures
  #   curl -fsSO $B/ledger-live-desktop-$V.sha512sum -fsSO $B/ledger-live-desktop-$V.sha512sum.sig
  #   # Key: LedgerHQ/ledger-live apps/ledger-live-desktop/src/main/updater/ledger-pubkey.ts,
  #   # cross-check against https://www.ledger.com/ledger-live/lld-signatures
  #   openssl dgst -sha256 -verify ledger-pubkey.pem \
  #     -signature ledger-live-desktop-$V.sha512sum.sig ledger-live-desktop-$V.sha512sum
  #   # Must print "Verified OK". Then convert the linux-x86_64.AppImage line:
  #   nix hash convert --hash-algo sha512 --to sri <hex>
  flake.modules.nixos.workstation =
    { pkgs, ... }:
    {
      nixpkgs.overlays = [
        (_final: prev: {
          ledger-live-desktop =
            let
              pname = "ledger-live-desktop";
              version = "4.28.0";

              src = prev.fetchurl {
                url = "https://download.live.ledger.com/${pname}-${version}-linux-x86_64.AppImage";
                hash = "sha512-v0EyXVS6hwe3VSYlxv9hS0NAafayun9Mbtg39U/x71eHqI2YEGBL7K8ly9zkwtwlu4HecldRVR0KBB2l2X3A6g==";
              };

              appimageContents = prev.appimageTools.extract { inherit pname version src; };
            in
            prev.appimageTools.wrapType2 {
              inherit pname version src;

              nativeBuildInputs = [ prev.makeWrapper ];

              extraInstallCommands = ''
                install -m 444 -D ${appimageContents}/${pname}.desktop $out/share/applications/${pname}.desktop
                install -m 444 -D ${appimageContents}/${pname}.png $out/share/icons/hicolor/1024x1024/apps/${pname}.png
                ${prev.imagemagick}/bin/magick ${appimageContents}/${pname}.png -resize 512x512 ${pname}_512.png
                install -m 444 -D ${pname}_512.png $out/share/icons/hicolor/512x512/apps/${pname}.png

                wrapProgram "$out/bin/${pname}" \
                  --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

                substituteInPlace $out/share/applications/${pname}.desktop \
                  --replace-fail 'Exec=AppRun' 'Exec=${pname}'
              '';

              inherit (prev.ledger-live-desktop) meta;
            };
        })
      ];

      # udev rules so the device is reachable over USB HID without root.
      hardware.ledger.enable = true;

      environment.systemPackages = [ pkgs.ledger-live-desktop ];
    };
}
