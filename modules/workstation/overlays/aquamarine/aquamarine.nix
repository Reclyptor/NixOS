_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        # Switching the monitor's input away from DisplayPort and back drops the DP
        # hot-plug line. The connector comes back, aquamarine modesets it and arms a
        # page-flip -- and the kernel never delivers that flip's completion event.
        #
        # Nothing in aquamarine 0.15.0 bounds that wait. CFrameScheduler holds the
        # frame pending forever, CDRMOutput::commitState answers every later buffer
        # commit with "Cannot commit when a page-flip is awaiting", and scheduleFrame
        # returns early on canSchedule(), so no caller is left to ask for the frame
        # that would clear the flag. The screen stays dark until a modeset tears the
        # CRTC down, which is why cycling DPMS by hand is the only way back.
        #
        # The patch stamps the frame when it is submitted and drops it when a caller
        # finds it still outstanding a second later. Its own comments carry the full
        # reasoning. Upstream reports the same failure from three other directions:
        # hyprwm/aquamarine#240 (HDMI hotplug), #382 (i915 MST resume) and #390
        # (amdgpu flip_done timeout), so this is offered upstream rather than kept
        # here indefinitely -- drop the override once it lands in a release.
        #
        # hyprland links aquamarine, so overriding it here rebuilds hyprland too.
        aquamarine = prev.aquamarine.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./aquamarine-reap-stalled-page-flips.patch ];
        });
      })
    ];
  };
}
