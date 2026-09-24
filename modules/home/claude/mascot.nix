_: {
  flake.modules.homeManager.base =
    {
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

        # Agents disagree on spelling: Claude Code sends session_id, Codex
        # sends sessionId. agentmemory's own hook reads both, so this does too
        # rather than guessing which harness invoked it.
        field() {
          printf '%s' "$payload" | ${pkgs.jq}/bin/jq -r \
            --arg a "$1" --arg b "''${2:-$1}" \
            '.[$a] // .[$b] // ""' 2>/dev/null || true
        }

        session="$(field session_id sessionId)"
        cwd="$(field cwd workdir)"
        agent="$(field agent_type subagent_type)"
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
      # one this needs most: it is the "working" signal.
      #
      # Clearing a prompt is a separate problem, and assuming PreToolUse did it is
      # what left the creature jumping after the user had already answered. Claude
      # Code fires nothing when a permission prompt is answered — PermissionRequest
      # runs *before* the prompt — so the device has to infer it from the next
      # thing the session does. UserPromptSubmit is that signal for an idle
      # notification, and PostToolUse for an approved tool; without them the only
      # way out was the following PreToolUse, which can be minutes away.
      programs.claudeCode.hooks = {
        PreToolUse = mkHook "working";
        PostToolUse = mkHook "working";
        UserPromptSubmit = mkHook "working";
        Notification = mkHook "needs_input";
        Stop = mkHook "finished";
        SubagentStop = mkHook "subagent_finished";
        PostToolUseFailure = mkHook "tool_failure";
        SessionStart = mkHook "session_start";
        SessionEnd = mkHook "session_end";
      };

      # Codex dispatches a smaller lifecycle set, and the difference is not
      # cosmetic: it has no Notification, so a Codex session cannot tell the
      # mascot it is waiting on you. What it can report is that it is working
      # and that it has stopped. PostToolUse stands in for PreToolUse, which
      # Codex does not dispatch either; it arrives a beat later but means the
      # same thing here.
      #
      # It also has no SessionEnd, so Codex rows are collected by the 30 minute
      # TTL rather than closed explicitly. That is exactly the case the TTL was
      # put there for.
      programs.codexCli.hooks = {
        SessionStart = mkHook "session_start";
        UserPromptSubmit = mkHook "working";
        PostToolUse = mkHook "working";
        Stop = mkHook "finished";
      };
    };
}
