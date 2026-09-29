_: {
  flake.modules.nixos.workstation = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      pavucontrol
      playerctl
    ];
    services.pipewire = {
      enable = true;
      audio.enable = true;
      pulse.enable = true;

      # The headphones publish themselves under their OEM's name ("Audiovance"
      # by TTGK Technology), which says nothing about what the device is or
      # where it plugs in. Name them for how they are actually used.
      wireplumber.extraConfig."51-usb-c-headphones" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "device.name" = "alsa_card.usb-TTGK_Technology_Co._Ltd_Audiovance-00"; }
            ];
            actions.update-props = {
              "device.description" = "USB-C Headphones";
              "device.nick" = "USB-C Headphones";
            };
          }
          {
            matches = [
              { "node.name" = "alsa_output.usb-TTGK_Technology_Co._Ltd_Audiovance-00.analog-stereo"; }
            ];
            actions.update-props = {
              "node.description" = "USB-C Headphones";
              "node.nick" = "USB-C Headphones";
            };
          }
          {
            matches = [
              { "node.name" = "alsa_input.usb-TTGK_Technology_Co._Ltd_Audiovance-00.mono-fallback"; }
            ];
            actions.update-props = {
              "node.description" = "USB-C Headphones Mic";
              "node.nick" = "USB-C Headphones Mic";
            };
          }
        ];
      };
    };
  };
}
