_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (final: prev: {
        # The Properties dialog's Video & Audio tabs probe media with
        # GStreamer's discoverer, and the wrapper's plugin path comes only
        # from nautilus's declared build inputs: the gstreamer core ships a
        # setup hook (addGstreamer1LibPath via addEnvHooks) that prefixes
        # each build input's lib/gstreamer-1.0 into
        # GST_PLUGIN_SYSTEM_PATH_1_0. nixpkgs's nautilus declares only
        # gst-plugins-base, which has no container demuxers and no codec
        # decoders (no qtdemux, no matroska — nixpkgs builds base without
        # libmatroska — no h264/hevc/aac/ac3), so every probe lands in the
        # "GStreamer installation is missing a plugin" dialog.
        #
        # Adding the remaining families as build inputs fixes it at the app
        # layer through that same hook — no env vars, no global state.
        # gst-libav is load-bearing for MKV: its avdemux is the only demuxer
        # nixpkgs provides for the format, and its avdec_* family is the
        # fallback decoder for anything the native plugins miss.
        nautilus = prev.nautilus.overrideAttrs (old: {
          buildInputs = old.buildInputs ++ [
            final.gst_all_1.gst-plugins-good
            final.gst_all_1.gst-plugins-bad
            final.gst_all_1.gst-plugins-ugly
            final.gst_all_1.gst-libav
          ];
        });
      })
    ];
  };
}
