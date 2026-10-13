/**
 * Deliver one event from a detached process: `node send-detached.js <endpoint> <json>`.
 *
 * The dsh TUI tears its plugins down and exits without disposing its agents,
 * so session_end can only be sent from the plugin's teardown, moments before
 * the process is gone. The teardown spawns this instead of waiting on a
 * socket, the same way the Claude Code hook hands its post to `setsid curl`.
 *
 * @module @reclyptor/mascot-agent-state/send-detached
 */

import { send } from './transport.js'

const [endpoint, json] = process.argv.slice(2)
await send(endpoint, JSON.parse(json))
