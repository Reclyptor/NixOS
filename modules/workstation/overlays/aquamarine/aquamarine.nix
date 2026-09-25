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
        # A disconnected output cannot be turned off either. commitState refuses every
        # commit once the connector reports disconnected, including the disable the
        # compositor issues from onDisconnect when the output goes away -- so that
        # disable never reaches the kernel and the CRTC stays active with the mode it
        # was last driving. recheckCRTCs only drops our own crtc assignment, which is
        # bookkeeping, not a commit. The next connect then modesets onto a CRTC that was
        # never torn down and the panel stays dark, which is why a manual DPMS off/on is
        # the only cure: by then the connector is back, so the same guard lets the
        # disable through. Reproduced twice, 2026-09-23 and 2026-09-24, both times with
        # zero rejected DPMS commits -- so this is a different fault from the toggle
        # latch patched in the hyprland overlay, not a second symptom of it.
        #
        # hyprland links aquamarine, so overriding it here rebuilds hyprland too.
        aquamarine = prev.aquamarine.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ./aquamarine-reap-stalled-page-flips.patch
            ./aquamarine-disable-disconnected-output.patch
          ];
        });
      })
    ];
  };
}
