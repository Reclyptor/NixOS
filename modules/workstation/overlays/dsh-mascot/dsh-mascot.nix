_: {
  flake.modules.nixos.workstation =
    { lib, ... }:
    {
      nixpkgs.overlays = [
        (final: prev: {
          # A dsh bundle that reports session state to the ESP32 desk mascot.
          #
          # Claude Code and Codex reach the device through their hook seams
          # (home/claude/mascot.nix). dsh does have a Claude Code hook bridge
          # since 0.2.0, but it does not dispatch PermissionRequest or
          # SessionEnd, so through it dsh could never say "waiting on you" and
          # its rows could only ever time out. The approval and user-question
          # waterfalls carry exactly that, so this is a native Cordis plugin on
          # dsh's own extension points instead.
          #
          # Every waterfall subscription is an observer: it delegates with
          # `await next()` and never alters the downstream decision, so
          # approvals, questions and tool dispatch behave exactly as they would
          # without it. The transport swallows every failure and is never
          # awaited, so the mascot being absent, asleep or mid-reflash cannot
          # disturb the harness.
          #
          # Source lives in ./bundle rather than being fetched: it is ours, and
          # vendoring it keeps the plugin and this comment in one commit.
          dsh-mascot =
            let
              self = prev.stdenvNoCC.mkDerivation {
                pname = "dsh-mascot-agent-state";
                version = "0.2.0";

                src = ./bundle;

                dontBuild = true;
                dontFixup = true;

                installPhase = ''
                  runHook preInstall
                  mkdir -p $out
                  cp -r . $out/

                  ${final.dsh-plugin-install} dsh-mascot src/index.js

                  runHook postInstall
                '';

                passthru = {
                  packageName = "@reclyptor/mascot-agent-state";
                  packageRoot = self;
                };

                meta = {
                  description = "dsh bundle reporting session state to the ESP32 desk mascot";
                  license = lib.licenses.mit;
                  platforms = lib.platforms.all;
                };
              };
            in
            self;
        })
      ];
    };
}
