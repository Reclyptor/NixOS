/**
 * Desk-mascot session reporter for any dsh frontend.
 *
 * A Cordis function plugin that reports each session's state to the ESP32
 * mascot over HTTP, from dsh's own extension points: the agent lifecycle
 * events and the approval / user-question / tool waterfalls. Those are dsh's
 * native seam - its Claude Code hook bridge does not dispatch
 * PermissionRequest, and "waiting on you" is the signal the device exists for.
 *
 * One process can host many agents (the web and headless frontends serve
 * several sessions, and every subagent is an agent too), so nothing here is a
 * process-wide singleton. Every event is attributed through the agent it
 * carries. A subagent reports against the root session that spawned it: the
 * human sees one conversation, and the device shows one row for it.
 *
 * Every waterfall subscription is an observer: it delegates with
 * `await next()` and never alters the downstream decision. Transport failures
 * are swallowed whole - the mascot being absent must not disturb the harness.
 *
 * The event names subscribed below are checked against the installed dsh at
 * build time (see dsh-mascot.nix), so a dsh release that renames one fails the
 * build instead of silently taking the mascot dark.
 *
 * @module @reclyptor/mascot-agent-state
 */

import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'

import z from '@deepseek-ai/schemastery'

import { send } from './transport.js'

const sendDetached = fileURLToPath(new URL('./send-detached.js', import.meta.url))

export const name = 'mascot-agent-state'

/** Reads events and the environment only; injects no services. */
export const inject = []

export const Config = z.object({
  /** Absolute URL of the device's event endpoint. */
  endpoint: z.string().default('http://192.168.1.7/event'),
  /** Label for this harness in the device's session table. */
  agent: z.string().default('dsh'),
  /** Set false to load the plugin inert, for debugging without the device. */
  enabled: z.boolean().default(true),
})

/**
 * Derive the repo label the device displays from a working directory: the
 * last two components, matching the Claude and Codex hook. Done here rather
 * than on the device, which has no idea what a worktree is.
 */
export function repoLabel(cwd) {
  if (typeof cwd !== 'string' || cwd === '') return ''
  const parts = cwd.split('/').filter(Boolean)
  if (parts.length === 0) return '/'
  return parts.slice(-2).join('/')
}

export function apply(ctx, config) {
  if (!config.enabled) return

  // Root session id per live agent id. A root maps to itself; a subagent maps
  // to its parent's root, which is registered first because a parent always
  // exists before the child it spawns.
  const roots = new Map()

  // Per root session: what was last reported, tool calls in flight, and the
  // tail of its post chain.
  const sessions = new Map()

  const sessionOf = (root) => {
    let s = sessions.get(root)
    if (s === undefined) {
      s = { cwd: process.cwd(), last: undefined, inFlight: 0, tail: Promise.resolve() }
      sessions.set(root, s)
    }
    return s
  }

  const rootOf = (agent) => {
    const id = agent?.id
    if (typeof id !== 'string' || id === '') return undefined
    return roots.get(id) ?? id
  }

  const bodyFor = (root, event) => {
    const s = sessionOf(root)
    return {
      event,
      session: root,
      agent: config.agent,
      host: process.env.HOSTNAME ?? '',
      repo: repoLabel(s.cwd),
      cwd: s.cwd,
      ts: Math.floor(Date.now() / 1000),
    }
  }

  // Posts for one session are chained, each waiting for the previous to
  // settle. Detached concurrent requests can land out of order, and the device
  // is last-write-wins: a `working` overtaking a `needs_input` hides a prompt
  // that is on screen. Chaining costs nothing the harness can feel - the chain
  // is never awaited, and every link is bounded by the transport timeout.
  const post = (root, event, { force = false } = {}) => {
    if (root === undefined) return
    const s = sessionOf(root)
    if (!force && event === s.last) return
    s.last = event
    const body = bodyFor(root, event)
    s.tail = s.tail.then(() => send(config.endpoint, body))
  }

  // The TUI never disposes its agents on quit: it tears down the plugin tree
  // and exits a few milliseconds later, so agent/disposed never arrives for
  // the sessions still open. This plugin's own teardown is the last signal,
  // and it is the right one anyway - once the reporter is gone, every session
  // it was reporting is unobservable. The process is about to exit and will
  // not wait on a socket, so each session_end is handed to a detached process.
  // Without this a quit session lingers on the device until its 30 minute TTL.
  ctx.effect(() => () => {
    for (const root of sessions.keys()) {
      spawn(process.execPath, [sendDetached, config.endpoint, JSON.stringify(bodyFor(root, 'session_end'))], {
        detached: true,
        stdio: 'ignore',
      }).unref()
    }
    sessions.clear()
    roots.clear()
  })

  ctx.on('agent/created', ({ agent }) => {
    const id = agent?.id
    if (typeof id !== 'string' || id === '') return
    const header = agent.session?.header
    const parent = header?.parentSession
    if (typeof parent === 'string' && parent !== '') {
      roots.set(id, roots.get(parent) ?? parent)
      return
    }
    roots.set(id, id)
    const s = sessionOf(id)
    if (typeof header?.cwd === 'string' && header.cwd !== '') s.cwd = header.cwd
    post(id, 'session_start', { force: true })
  })

  ctx.on('agent/status', ({ agent, status }) => {
    // A subagent going idle is not the conversation ending; only the root's
    // own run boundary is the equivalent of Claude's Stop.
    const root = rootOf(agent)
    if (root === undefined || root !== agent.id) return
    if (status === 'running') post(root, 'working')
    else post(root, 'finished', { force: true })
  })

  ctx.on('agent/disposed', ({ agent }) => {
    const root = rootOf(agent)
    if (root === undefined) return
    roots.delete(agent.id)
    if (root !== agent.id) {
      post(root, 'subagent_finished', { force: true })
      return
    }
    post(root, 'session_end', { force: true })
    sessions.delete(root)
  })

  // Blocked on a human: the two waterfalls that mean "waiting on you". A
  // subagent's prompt blocks the same human, so it lands on the root's row.
  const blocking = async (agent, next) => {
    const root = rootOf(agent)
    post(root, 'needs_input', { force: true })
    try {
      return await next()
    } finally {
      post(root, 'working', { force: true })
    }
  }

  ctx.on('approval/request', (req, next) => blocking(req?.agent, next))
  ctx.on('user-questions/request', (req, next) => blocking(req?.agent, next))

  // A burst of parallel calls is one transition rather than a stutter.
  ctx.on('tools/execute', async (exec, next) => {
    const root = rootOf(exec?.agent)
    const s = root === undefined ? undefined : sessionOf(root)
    if (s !== undefined && s.inFlight++ === 0) post(root, 'working')
    try {
      return await next()
    } finally {
      if (s !== undefined) s.inFlight = Math.max(0, s.inFlight - 1)
    }
  })

  ctx.on('tools/result', (exec, result) => {
    if (result?.isError === true) post(rootOf(exec?.agent), 'tool_failure', { force: true })
  })
}
