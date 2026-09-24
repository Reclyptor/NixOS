/**
 * Mascot HTTP transport.
 *
 * One fire-and-forget POST per state change. The contract this must honour is
 * the same one the Claude and Codex hooks honour, and it is the hardest
 * constraint in the design: a device that is unplugged, asleep or mid-reflash
 * must be indistinguishable from one that is working, from the harness's point
 * of view. So every failure is swallowed, nothing is retried, and no promise
 * returned from here ever rejects.
 *
 * Only node:http is used — no fetch, because its default timeout is unbounded
 * and an AbortController per request is more moving parts than a socket
 * timeout.
 *
 * @module @reclyptor/mascot-agent-state/transport
 */

import http from 'node:http'

/**
 * Deliver one event. Resolves true when the device acknowledged, false for any
 * failure at all. Never throws, never rejects.
 *
 * @param {string} endpoint absolute http URL
 * @param {object} body JSON-serialisable event payload
 * @param {number} [timeoutMs]
 * @returns {Promise<boolean>}
 */
export function send(endpoint, body, timeoutMs = 400) {
  return new Promise((resolve) => {
    let settled = false
    let deadline
    let req
    const finish = (ok) => {
      if (settled) return
      settled = true
      clearTimeout(deadline)
      req?.destroy()
      resolve(ok)
    }

    let url
    let payload
    try {
      url = new URL(endpoint)
      payload = JSON.stringify(body)
    } catch {
      finish(false)
      return
    }

    req = http.request(
      {
        protocol: url.protocol,
        hostname: url.hostname,
        port: url.port || 80,
        path: url.pathname,
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'content-length': Buffer.byteLength(payload),
        },
      },
      (res) => {
        // Drain rather than leaving the socket half-read, then judge the code.
        res.resume()
        res.on('end', () => finish(res.statusCode >= 200 && res.statusCode < 300))
      },
    )

    // An absolute deadline, not just a socket timeout. `setTimeout` on a
    // ClientRequest bounds idle time on an established socket; it does not
    // bound name resolution or the TCP connect, so an unreachable host hangs
    // for the OS connect timeout - measured at 3 s on a quiet LAN address and
    // 5 s on an unroutable one. Nothing awaits this, so it cannot stall the
    // harness, but a request left dangling for five seconds per event is a
    // resource leak waiting to be noticed under a burst.
    deadline = setTimeout(() => finish(false), timeoutMs)
    deadline.unref?.()   // never hold the process open on the mascot's account

    req.setTimeout(timeoutMs, () => finish(false))
    req.on('error', () => finish(false))
    req.end(payload)
  })
}
