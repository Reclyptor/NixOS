/**
 * Self-diagnosis for a skin that is expected to break.
 *
 * Every DOM read goes through `q`/`qa` and every decoration through `guard`,
 * so this module accumulates a live picture of which parts of the skin are
 * still finding their targets. `window.__DSH_SKIN__.diagnose()` prints it.
 *
 * The intended repair loop after a dsh upgrade:
 *   1. Something looks wrong.
 *   2. `__DSH_SKIN__.diagnose()` in devtools.
 *   3. Read the MISS rows and their `breaks` notes.
 *   4. Fix those rows in `selectors.ts`. Every theme is repaired at once.
 */
import { SELECTORS, type SelectorKey, type SelectorSpec } from './selectors.ts'

/** Live state for one selector row. */
interface SelectorHealth {
  /** Matches at the most recent resolution attempt. */
  matched: number
  /** Whether the selector has ever been resolved this activation. */
  probed: boolean
}

/** One recorded decoration failure. */
export interface DecorationFailure {
  readonly key: string
  readonly message: string
}

const health = new Map<SelectorKey, SelectorHealth>()
const failures: DecorationFailure[] = []

/** Whether a match count satisfies the row's declared arity. */
function satisfied(spec: SelectorSpec, matched: number): boolean {
  return spec.arity === 'optional' ? true : matched > 0
}

function record(key: SelectorKey, matched: number): void {
  health.set(key, { matched, probed: true })
}

/**
 * Resolve a selector to at most one element, recording the outcome.
 * Never throws and never returns a rejected promise: a missing element is an
 * expected state that degrades exactly one decoration.
 * @param key - row in {@link SELECTORS}.
 * @param root - subtree to search; defaults to the document.
 * @returns the first match, or null.
 */
export function q<E extends Element = HTMLElement>(
  key: SelectorKey,
  root: ParentNode = document,
): E | null {
  const found = root.querySelector<E>(SELECTORS[key].selector)
  record(key, found === null ? 0 : 1)
  return found
}

/**
 * Resolve a selector to every match, recording the outcome.
 * @param key - row in {@link SELECTORS}.
 * @param root - subtree to search; defaults to the document.
 * @returns all matches, possibly empty.
 */
export function qa<E extends Element = HTMLElement>(
  key: SelectorKey,
  root: ParentNode = document,
): E[] {
  const found = [...root.querySelectorAll<E>(SELECTORS[key].selector)]
  record(key, found.length)
  return found
}

/**
 * Run one decoration in isolation.
 *
 * This is deliberately NOT a swallowed exception: the failure is logged with
 * its key and retained for {@link diagnose}, so it is louder after the fact
 * than an uncaught throw would have been. The boundary exists because the
 * decorations are independent — one broken ornament must not cost the user
 * the other fifteen, or the palette, or the disposer that cleans all of it up.
 * @param key - decoration name, surfaced in logs and diagnostics.
 * @param run - the decoration.
 */
export function guard(key: string, run: () => void): void {
  try {
    run()
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    failures.push({ key, message })
    console.error(`[dsh-skin] decoration "${key}" failed: ${message}`, error)
  }
}

/** One row of the printed diagnostic table. */
interface DiagnosticRow {
  tier: SelectorTier
  status: 'OK' | 'MISS' | 'unprobed'
  matched: number | '-'
  selector: string
  breaks: string
}

type SelectorTier = SelectorSpec['tier']

function rows(): Record<string, DiagnosticRow> {
  const table: Record<string, DiagnosticRow> = {}
  for (const key of Object.keys(SELECTORS) as SelectorKey[]) {
    const spec = SELECTORS[key]
    const state = health.get(key)
    table[key] = {
      tier: spec.tier,
      status: state === undefined
        ? 'unprobed'
        : satisfied(spec, state.matched) ? 'OK' : 'MISS',
      matched: state === undefined ? '-' : state.matched,
      selector: spec.selector,
      breaks: spec.breaks,
    }
  }
  return table
}

/** Selector keys currently failing their declared arity. */
export function failingSelectors(): SelectorKey[] {
  return (Object.keys(SELECTORS) as SelectorKey[]).filter((key) => {
    const state = health.get(key)
    return state !== undefined && !satisfied(SELECTORS[key], state.matched)
  })
}

/**
 * Warn once, after the first decoration pass, if anything is already broken.
 * Points at {@link diagnose} rather than dumping the whole table into the
 * console on every boot.
 * @param id - the active theme id, so the message names the skin.
 */
export function reportBootHealth(id: string): void {
  const failing = failingSelectors()
  if (failing.length === 0 && failures.length === 0) return
  console.warn(
    `[dsh-skin] "${id}" booted with ${failing.length} stale selector(s)`
    + `${failures.length > 0 ? ` and ${failures.length} failed decoration(s)` : ''}`
    + `: ${[...failing, ...failures.map(f => f.key)].join(', ')}.`
    + ' Run __DSH_SKIN__.diagnose() for the full table.',
  )
}

/**
 * Install the devtools entry point. Registered on activation and removed by
 * the disposer so a hot theme switch cannot leave a stale handle behind.
 * @param id - active theme id.
 * @param packageName - active skin package, echoed for bug reports.
 * @returns a disposer removing the global.
 */
export function installDiagnostics(id: string, packageName: string): () => void {
  const api = {
    id,
    packageName,
    /** Print the live selector table. */
    diagnose(): void {
      console.info(`[dsh-skin] ${packageName}`)
      console.table(rows())
      if (failures.length > 0) console.table(failures)
    },
    /** Selector keys currently failing their declared arity. */
    failing: failingSelectors,
    /** Decoration failures recorded this activation. */
    failures: (): readonly DecorationFailure[] => [...failures],
  }
  Reflect.set(globalThis, '__DSH_SKIN__', api)
  return () => {
    if (Reflect.get(globalThis, '__DSH_SKIN__') === api) {
      Reflect.deleteProperty(globalThis, '__DSH_SKIN__')
    }
  }
}

/** Drop all recorded state. Called by the disposer so a re-activation starts clean. */
export function resetDiagnostics(): void {
  health.clear()
  failures.length = 0
}
