_: {
  flake.modules.homeManager.base =
    {
      lib,
      pkgs,
      ...
    }:
    let
      # The ESP32-S3 desk mascot that reports Claude Code session state. Its
      # firmware, artwork and the contract for this payload live in
      # ~/Projects/esp32/amoled (see SPEC.md, "Event model").
      #
      # Addressed by IP rather than claude.local: mDNS resolution needs avahi
      # wired into NSS on every machine that posts, and a DHCP reservation needs
      # nothing. The device advertises the name regardless, for humans.
      mascotHost = "192.168.1.7";

      # THE HARDEST CONSTRAINT IN THIS FILE: a hook must never block or fail a
      # session. A device that is unplugged, asleep, or mid-reflash has to be
      # indistinguishable from one that is working, from Claude Code's point of
      # view. So: detached with setsid so the session never waits on it, a hard
      # timeout well under a second, all output discarded, and an unconditional
      # exit 0 no matter what curl thought.
      #
      # The payload is read from the hook's own stdin JSON. `session_id` and
      # `cwd` are what Claude Code provides; `repo` is derived here rather than
      # on the device, which has no idea what a worktree is.
      mascotHook = pkgs.writeShellScript "claude-mascot-hook" ''
        set -u
        event="''${1:-}"
        payload="$(cat 2>/dev/null || true)"

        field() {
          printf '%s' "$payload" \
            | ${pkgs.jq}/bin/jq -r --arg k "$1" '.[$k] // ""' 2>/dev/null || true
        }

        session="$(field session_id)"
        cwd="$(field cwd)"
        agent="$(field agent_type)"
        [ -n "$session" ] || exit 0

        # "esp32/amoled" from a path, and the session id from a worktree name if
        # the directory is one, so every worktree of a repo reads distinctly.
        repo="$(basename "$(dirname "$cwd")")/$(basename "$cwd")"

        body="$(${pkgs.jq}/bin/jq -nc \
          --arg event "$event" --arg session "$session" --arg agent "$agent" \
          --arg host "$(hostname)" --arg repo "$repo" --arg cwd "$cwd" \
          '{event:$event, session:$session, agent:$agent, host:$host,
            repo:$repo, cwd:$cwd, ts:(now|floor)}' 2>/dev/null || true)"
        [ -n "$body" ] || exit 0

        ${pkgs.util-linux}/bin/setsid -f ${pkgs.curl}/bin/curl \
          --silent --show-error --output /dev/null \
          --max-time 0.4 --connect-timeout 0.2 \
          --header 'Content-Type: application/json' \
          --data-binary "$body" \
          'http://${mascotHost}/event' >/dev/null 2>&1 || true

        exit 0
      '';

      mkHook = event: [
        {
          hooks = [
            {
              type = "command";
              command = "${mascotHook} ${event}";
            }
          ];
        }
      ];
    in
    {
      # Contributed to the list-merging option in home/claude/claude.nix, so these
      # land BESIDE the agentmemory entries rather than replacing them: per-event
      # lists concatenate across modules.
      #
      # PreToolUse is the only event agentmemory deliberately omits, and it is the
      # one this needs most — it is both the "working" signal and the ordinary way
      # a prompt clears.
      programs.claudeCode.hooks = {
        PreToolUse = mkHook "working";
        Notification = mkHook "needs_input";
        Stop = mkHook "finished";
        SubagentStop = mkHook "subagent_finished";
        PostToolUseFailure = mkHook "tool_failure";
        SessionStart = mkHook "session_start";
        SessionEnd = mkHook "session_end";
      };
    };
}
