// Reports the running dsh session's identity to herdr, so herdr can resume the
// same conversation after a server restart.
//
// Identity ONLY — never lifecycle state. herdr treats an integration that
// reports state as the authority for that agent and stops consulting its screen
// manifest, and the manifest's blocked detection (the approval bar) is both
// proven and more complete than anything these events give us. Upstream's own
// Claude and Codex integrations draw the line in exactly the same place.
import { execFile } from 'node:child_process';

export const name = 'herdr-session';

const SOURCE = 'herdr:deepseek';
const AGENT = 'deepseek';

// dsh emits session/event for every seq in the session log; the id only matters
// when it changes, so report once per id and stay silent after that.
export function apply(ctx) {
  const pane = process.env.HERDR_PANE_ID;
  const socket = process.env.HERDR_SOCKET_PATH;
  if (process.env.HERDR_ENV !== '1' || !pane || !socket) return;

  let reported;
  const report = (id) => {
    if (!id || id === reported) return;
    reported = id;
    // Best effort by design: herdr being absent, older, or busy must never
    // disturb the pane it is reporting about.
    execFile(
      'herdr',
      ['pane', 'report-agent-session', '--source', SOURCE, '--agent', AGENT, '--agent-session-id', id, pane],
      { timeout: 5000 },
      () => {},
    );
  };

  ctx.on('session/event', (session) => {
    report(session?.header?.id);
  });
}
