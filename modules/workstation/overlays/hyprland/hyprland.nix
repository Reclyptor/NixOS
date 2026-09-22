_: {
  flake.modules.nixos.workstation = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        # SUPER + D turns the monitor off reliably but sometimes fails to bring it back,
        # and then the first several presses do nothing at all before the picture returns.
        #
        # CMonitor::setDPMS sets its cached DPMS state before the commit that is supposed
        # to realise it, and returns early whenever that cache already matches the request.
        # commitDPMSState retries once, two frames later -- 8ms on this 240Hz output -- and
        # then gives up. One rejected enable is therefore enough to leave the compositor
        # reporting a monitor that is on while the panel is dark, with every subsequent
        # "dpms on" discarded by the early return before it reaches the hardware. Only
        # toggling to off and back re-attempts it. Nothing on the sink side recovers it,
        # which is what rules the monitor out: power cycling the display, reseating
        # DisplayPort and switching its input were each tried and none of them help.
        #
        # The patch separates the state that committed from the state that was requested,
        # backs the retries off across seconds instead of milliseconds, and reconciles the
        # two when it does give up, so the next press starts from what is really on screen.
        #
        # The toggle action reads the requested state rather than the committed one. Those
        # were the same thing before the split, and deriving a toggle from what committed
        # is what kept the G9 dark after it powered its DisplayPort input down: the first
        # press asks to disable, the commit is rejected, and because nothing committed the
        # next press asks to disable *again* and is dropped as redundant while the retry is
        # still outstanding. Every press does nothing until the retries run out, which is
        # the "press it five times" dance seen on 2026-09-22. Its own comments carry the
        # reasoning. Offered upstream rather than kept here indefinitely -- drop the
        # override once it lands in a release.
        hyprland = prev.hyprland.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./hyprland-retry-rejected-dpms-commits.patch ];
        });
      })
    ];
  };
}
