/**
 * Desk-mascot session reporter for any dsh frontend.
 *
 * A Cordis function plugin that reports the session's semantic state to the
 * ESP32 mascot over HTTP. It uses only documented dsh extension points — the
 * agent lifecycle events, and the approval / user-question / tool-dispatch
 * waterfalls — so it works in TUI, web and headless profiles alike.
 *
 * The waterfalls are what make dsh worth wiring at all: they give a real
 * "waiting on you" signal, which Codex cannot produce and which is the whole
 * point of the device. Claude Code has the same signal via its Notification
 * hook; dsh has no hooks, which is why this exists as a bundle instead.
 *
 * Every subscription that participates in a waterfall is an observer: it
 * delegates with `await next()` and never alters the downstream decision, so
 * approvals, questions and tool dispatch behave exactly as they would without
 * it. Transport failures are swallowed whole — the mascot being absent must not
 * disturb the harness.
 *
 * Ships as plain ESM (no build step) so `dsh plugin add` loads it directly.
 *
 * @module @reclyptor/mascot-agent-state
 */

import z from '@deepseek-ai/schemastery'

import { send } from './transport.js'

export const name = 'mascot-agent-state'

/** Reads events and the environment only; injects no services. */
export const inject = []

export const Config = z.object({
  /** Absolute URL of the device's event endpoint. */
  endpoint: z.string().default('http://192.168.1.7/event'),
  /**
   * Stable identity for this harness in the device's session table. The device
   * keys rows by session id, so this only labels which agent produced them.
   */
  agent: z.string().default('dsh'),
  /** Set false to load the plugin inert, for debugging without the device. */
  enabled: z.boolean().default(true),
})

/**
 * Derive the repo label the device displays, from the session's working
 * directory. Done here rather than on the device, which has no idea what a
 * worktree is.
 */
function repoLabel(cwd) {
  if (typeof cwd !== 'string' || cwd === '') return ''
  const parts = cwd.replace(/\/+$/, '').split('/').filter(Boolean)
  if (parts.length === 0) return ''
  return parts.length === 1 ? parts[0] : `${parts[parts.length - 2]}/${parts[parts.length - 1]}`
}

export function apply(ctx, config) {
  if (!config.enabled) return

  // One row per dsh session. Until a session-start arrives there is nothing
  // meaningful to key on, so events before it are dropped rather than
  // attributed to a made-up id.
  let sessionId
  let repo = repoLabel(process.cwd())

  // How many tool calls are in flight. `working` is reported on the first and
  // the state is left alone until the last one drains, so a burst of parallel
  // calls is one transition rather than a stutter.
  let inFlight = 0

  // The device debounces `working` itself, but sending one POST per tool call
  // would still put avoidable traffic on a radio that shares a USB rail with
  // the host's input devices. Report only on change.
  let lastReported

  const post = (event, force = false) => {
    if (sessionId === undefined) return
    if (!force && event === lastReported) return
    lastReported = event
    // Deliberately not awaited: the harness must never wait on the device.
    void send(config.endpoint, {
      event,
      session: sessionId,
      agent: config.agent,
      host: process.env.HOSTNAME ?? '',
      repo,
      cwd: process.cwd(),
      ts: Math.floor(Date.now() / 1000),
    })
  }

  ctx.on('agent/session-start', (payload) => {
    const session = payload?.agent?.session
    const id = session?.header?.id
    if (typeof id === 'string' && id !== '') {
      sessionId = id
      repo = repoLabel(process.cwd())
      lastReported = undefined
      post('session_start', true)
    }
  })

  ctx.on('agent/status', (payload) => {
    // A run ending is the closest thing dsh has to Claude's Stop.
    if (payload?.status === 'running') post('working')
    else post('finished', true)
  })

  ctx.on('agent/disposed', () => {
    post('session_end', true)
    sessionId = undefined
  })

  // Blocked on a human: the two waterfalls that mean "waiting on you".
  ctx.on('approval/request', async (req, next) => {
    post('needs_input', true)
    try {
      return await next()
    } finally {
      // Answered. Back to working; the device clears the prompt on any of
      // several signals, and this is the ordinary one.
      post('working', true)
    }
  })

  ctx.on('user-questions/request', async (request, next) => {
    post('needs_input', true)
    try {
      return await next()
    } finally {
      post('working', true)
    }
  })

  ctx.on('tools/execute', async (exec, next) => {
    if (inFlight === 0) post('working')
    inFlight += 1
    try {
      return await next()
    } finally {
      inFlight = Math.max(0, inFlight - 1)
    }
  })

  ctx.on('tools/result', (exec) => {
    // dsh surfaces a failed call as a result carrying an error rather than by
    // throwing, so this is the only place a tool failure is observable.
    const failed = exec?.isError === true || exec?.error !== undefined
    if (failed) post('tool_failure', true)
  })
}
