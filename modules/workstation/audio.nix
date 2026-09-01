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

      # The USB-C earbuds use a Synaptics audio chip that reports Razer's
      # vendor ID (1532:0504), so udev's hwdb resolves them to "Kraken 7.1
      # Chroma" and WirePlumber prefers that over the descriptor's real
      # ID_MODEL. Name the device for what it actually is.
      wireplumber.extraConfig."51-usb-c-earbuds" = {
        "monitor.alsa.rules" = [
          {
            matches = [ { "device.name" = "alsa_card.usb-Synaptics_USB-C_HEADSET_00000000-00"; } ];
            actions.update-props = {
              "device.description" = "USB-C Earbuds";
              "device.nick" = "USB-C Earbuds";
            };
          }
          {
            matches = [
              { "node.name" = "alsa_output.usb-Synaptics_USB-C_HEADSET_00000000-00.analog-stereo"; }
            ];
            actions.update-props = {
              "node.description" = "USB-C Earbuds";
              "node.nick" = "USB-C Earbuds";
            };
          }
          {
            matches = [ { "node.name" = "alsa_input.usb-Synaptics_USB-C_HEADSET_00000000-00.mono-fallback"; } ];
            actions.update-props = {
              "node.description" = "USB-C Earbuds Mic";
              "node.nick" = "USB-C Earbuds Mic";
            };
          }
        ];
      };
    };
  };
}
