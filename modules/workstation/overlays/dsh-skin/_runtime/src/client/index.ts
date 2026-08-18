/**
 * The theme-agnostic skin engine.
 *
 * Everything here is driven by {@link ThemeManifest}; nothing in this file
 * knows which theme is active. Adding a theme never edits this file — that is
 * the point of the split, because it means a repair after a dsh upgrade fixes
 * every theme at once.
 *
 * The engine owns three kinds of output, all consumed by the theme stylesheet:
 *
 *   1. Art and geometry custom properties, written through CSSOM.
 *   2. Projected state: app state mirrored onto body `data-skin-*` attributes,
 *      so the stylesheet stays declarative and never queries the DOM itself.
 *   3. Decoration nodes it inserts and exclusively owns.
 *
 * Two invariants hold the design together:
 *
 *   - The disposer is registered BEFORE any fallible work and restores exact
 *     captured values. Hot-switching themes must leave nothing behind.
 *   - Continuous values are written through CSSOM, never `body.style`. A CSSOM
 *     write produces no attribute mutation, so per-frame updates cannot wake
 *     the app's own MutationObservers (Chrome's autofill watcher in
 *     particular) sixty times a second.
 */
import type { Context } from '@deepseek-ai/cordis'
// Type-only: pulls in the module augmentation that puts `theme` on Context.
import type {} from '@deepseek-ai/dsh-client-ui-theme/client'
import { MANIFEST } from './manifest.generated.ts'
import STRUCTURE from './structure.css'
import { guard, installDiagnostics, q, qa, reportBootHealth, resetDiagnostics } from './diagnostics.ts'
import { SELECTORS } from './selectors.ts'

/**
 * Cordis services this plugin reads off `ctx`. `theme` is mandatory, not
 * optional: cordis refuses `ctx.theme` outright ("cannot get property theme
 * without inject") unless the service is declared here, which silently costs
 * the entire palette — every surface and label token — while the art still
 * loads and makes the skin look merely misconfigured rather than broken.
 *
 * These are SERVICE names. The package-level `dsh.client.inject` in the
 * generated package.json is a different list that takes PACKAGE names and
 * orders the client boot graph; both are required.
 */
export const inject = ['theme']

/** Fallback title-bar height for the desktop shell, whose row is fixed. */
const DESKTOP_TITLEBAR_HEIGHT_PX = 32

/** How long after the last resize event the resizing state is held. */
const VIEWPORT_RESIZE_SETTLE_MS = 120

/** Composer rise/dock animation window, matched to the stylesheet. */
const COMPOSER_MOTION_MS = 560

/** Marks every node and style tag this skin owns, for cleanup and self-recognition. */
const OWNER_ATTRIBUTE = 'data-skin-owner'

/** Body attributes carrying projected app state. Values are presence-only. */
const STATE = {
  chatActive: 'data-skin-chat-active',
  conversationActive: 'data-skin-conversation-active',
  betterSidebarOpen: 'data-skin-better-sidebar-open',
  cordisPanelOpen: 'data-skin-cordis-panel-open',
  settingsOpen: 'data-skin-settings-open',
  workspace: 'data-skin-workspace',
} as const

/** Decoration attributes the engine writes onto app-owned elements. */
const DECORATED = [
  'data-skin-sidebar-footer',
  'data-skin-workspace-group',
  'data-skin-workspace-row',
  'data-skin-workspace-active',
  'data-skin-session-row',
  'data-skin-session-flat',
  'data-skin-session-first',
  'data-skin-session-last',
] as const

/** Sidebar width thresholds, matching the stylesheet's size cases. */
const SIDEBAR_RAIL_MAX_PX = 120
const SIDEBAR_NARROW_MAX_PX = 220
const SIDEBAR_COMPACT_MAX_PX = 104

interface AttributeLease {
  acquire: () => void
  release: () => void
}

interface LeaseState {
  originalValue: string | null
  owners: Set<symbol>
  value: string
}

const leases = new WeakMap<HTMLElement, Map<string, LeaseState>>()

/**
 * Refcounted body-attribute ownership. Two activations (a hot theme switch
 * overlapping its predecessor's teardown) must not clobber each other's
 * restore value: the first acquirer captures the original, the last releaser
 * puts it back.
 */
function createAttributeLease(body: HTMLElement, attribute: string, value = ''): AttributeLease {
  const owner = Symbol(attribute)
  let active = false

  return {
    acquire(): void {
      if (active) return
      let attributes = leases.get(body)
      if (attributes === undefined) {
        attributes = new Map()
        leases.set(body, attributes)
      }
      let state = attributes.get(attribute)
      if (state === undefined) {
        state = { originalValue: body.getAttribute(attribute), owners: new Set(), value }
        attributes.set(attribute, state)
      }
      state.owners.add(owner)
      active = true
      body.setAttribute(attribute, state.value)
    },
    release(): void {
      if (!active) return
      active = false
      const attributes = leases.get(body)
      const state = attributes?.get(attribute)
      if (state === undefined || !state.owners.delete(owner)) return
      if (state.owners.size > 0) return
      attributes?.delete(attribute)
      if (attributes?.size === 0) leases.delete(body)
      if (body.getAttribute(attribute) !== state.value) return
      if (state.originalValue === null) body.removeAttribute(attribute)
      else body.setAttribute(attribute, state.originalValue)
    },
  }
}

/**
 * Whether the GPU can composite the large blurred surfaces this kind of theme
 * leans on. A software-only context degrades to a CPU-safe path in CSS rather
 * than dropping frames.
 */
function hasAcceleratedWebGL(): boolean {
  if (typeof WebGLRenderingContext === 'undefined') return false
  const canvas = document.createElement('canvas')
  const options: WebGLContextAttributes = { failIfMajorPerformanceCaveat: true }
  // Spelled as separate thunks rather than a loop over a union of context
  // names: getContext is overloaded per name, and a union argument collapses
  // the return to RenderingContext, which has no getExtension.
  const attempts = [
    () => canvas.getContext('webgl2', options),
    () => canvas.getContext('webgl', options),
  ]
  for (const attempt of attempts) {
    try {
      const context = attempt()
      if (context === null) continue
      context.getExtension('WEBGL_lose_context')?.loseContext()
      return true
    } catch {
      // A blocked or software-only context uses the CPU-safe CSS path.
    }
  }
  return false
}

/**
 * The art and decoration custom properties, as stylesheet text.
 *
 * These were previously written through CSSOM, one setProperty per slot. Each
 * value is a base64 data URI up to a few hundred kilobytes, so that pushed
 * roughly two megabytes of string through the CSSOM API at boot. Chromium
 * tolerates it; Gecko is markedly worse with very large property values, and
 * the whole client boot is downstream of this running. None of it is dynamic,
 * so it belongs in a sheet the CSS parser reads once.
 *
 * Both backdrops are declared here too, selected by the dark-scheme attribute
 * rather than swapped from script — same reason, and it removes a MutationObserver
 * write from the theme-change path.
 */
function artSheet(id: string): string {
  const { art, decoration } = MANIFEST
  const scope = `body[data-dsh-skin='${id}']`
  const vars: [string, string][] = [
    ['--skin-top-trim', `url(${art.topTrimTile})`],
    ['--skin-bottom-trim', `url(${art.bottomTrimTile})`],
    ['--skin-bottom-crest', `url(${art.bottomCrest})`],
    ['--skin-accent-bow', `url(${art.accentBow})`],
    ['--skin-new-session', `url(${art.newSession})`],
    ['--skin-sidebar-swag', `url(${art.sidebarSwag})`],
    ['--skin-sidebar-corner', `url(${art.sidebarCorner})`],
    ['--skin-composer-frame', `url(${art.composerFrame})`],
    ['--skin-settings-frame', `url(${art.settingsFrame})`],
    ['--skin-workspace-shield', `url(${art.workspaceShield})`],
    ['--skin-workspace-ribbon', `url(${art.workspaceRibbon})`],
    ['--skin-backdrop', `url(${art.backdropLight})`],
  ]
  for (const [name, value] of Object.entries(decoration)) vars.push([name, value])
  const body = vars.map(([n, v]) => `  ${n}: ${v};`).join('\n')
  return `${scope} {\n${body}\n}\n`
    + `${scope}[data-ds-dark-theme] {\n  --skin-backdrop: url(${art.backdropDark});\n}\n`
}

/**
 * Apply the skin. Every write registered here is retracted by the effect
 * disposer.
 * @param ctx - owning cordis context.
 */
export function apply(ctx: Context): void {
  const body = document.body
  const originalTitle = document.title
  const owned = new Set<Element>()
  const decorated = new Set<HTMLElement>()
  // One generic attribute carrying the theme id. The shared structure sheet
  // selects `body[data-dsh-skin]`; a theme's own sheet selects
  // `body[data-dsh-skin='<id>']`, which is strictly more specific and so wins
  // every tie without either sheet knowing about the other.
  const skinAttribute = 'data-dsh-skin'

  const skinLease = createAttributeLease(body, skinAttribute, MANIFEST.id)
  const resizingLease = createAttributeLease(body, 'data-skin-viewport-resizing')
  const lowPowerLease = createAttributeLease(body, 'data-skin-low-power')

  const previousState = new Map<string, string | null>()
  for (const attribute of Object.values(STATE)) {
    previousState.set(attribute, body.getAttribute(attribute))
  }

  let themeColorMeta: HTMLMetaElement | null = null
  let originalThemeColor: string | null = null
  let themeColorObserver: MutationObserver | undefined
  let observer: MutationObserver | undefined
  let resizeObserver: ResizeObserver | undefined
  let observedSidebar: HTMLElement | undefined
  let removeTokens: (() => void) | undefined
  let composerPhase: 'hero' | 'active' | undefined
  let composerMotionTimer: ReturnType<typeof setTimeout> | undefined
  let resizeSettleTimer: ReturnType<typeof setTimeout> | undefined
  let onViewportResize: (() => void) | undefined
  let onDocumentClick: ((event: MouseEvent) => void) | undefined
  let searchFocusFrame: number | undefined
  let settingsBackdropFrame: HTMLElement | undefined

  const removeDiagnostics = installDiagnostics(MANIFEST.id, MANIFEST.packageName)

  // Registered before any fallible work below, so a throw mid-application
  // still tears down whatever had already been applied.
  ctx.effect(() => () => {
    observer?.disconnect()
    themeColorObserver?.disconnect()
    if (observedSidebar !== undefined) resizeObserver?.unobserve(observedSidebar)
    resizeObserver?.disconnect()
    if (composerMotionTimer !== undefined) clearTimeout(composerMotionTimer)
    if (resizeSettleTimer !== undefined) clearTimeout(resizeSettleTimer)
    if (searchFocusFrame !== undefined) cancelAnimationFrame(searchFocusFrame)
    if (onViewportResize !== undefined) window.removeEventListener('resize', onViewportResize)
    if (onDocumentClick !== undefined) document.removeEventListener('click', onDocumentClick)
    removeTokens?.()
    resizingLease.release()
    lowPowerLease.release()
    skinLease.release()
    body.removeAttribute('data-skin-sidebar-size')
    body.removeAttribute('data-skin-sidebar-compact')
    body.removeAttribute('data-skin-composer-motion')
    for (const [attribute, value] of previousState) {
      if (value === null) body.removeAttribute(attribute)
      else body.setAttribute(attribute, value)
    }
    decorated.forEach((element) => {
      for (const attribute of DECORATED) element.removeAttribute(attribute)
    })
    owned.forEach(element => element.remove())
    if (themeColorMeta?.isConnected === true
      && themeColorMeta.content === MANIFEST.systemChromeColor) {
      if (originalThemeColor === null) themeColorMeta.removeAttribute('content')
      else themeColorMeta.content = originalThemeColor
    }
    if (document.title === MANIFEST.title) document.title = originalTitle
    removeDiagnostics()
    resetDiagnostics()
  }, `dsh-skin:${MANIFEST.id}`)

  /** Create a `<style>` this skin owns, appended to head and tracked for disposal. */
  const createOwnedStyle = (kind: string): HTMLStyleElement => {
    const style = document.createElement('style')
    style.setAttribute(OWNER_ATTRIBUTE, MANIFEST.id)
    style.dataset.skinStyle = kind
    owned.add(style)
    document.head.append(style)
    return style
  }

  /** Create an owned decoration element, tracked for disposal. */
  const createOwned = <K extends keyof HTMLElementTagNameMap>(
    tag: K,
    chrome: string,
  ): HTMLElementTagNameMap[K] => {
    const element = document.createElement(tag)
    element.setAttribute(OWNER_ATTRIBUTE, MANIFEST.id)
    element.dataset.skinChrome = chrome
    element.setAttribute('aria-hidden', 'true')
    owned.add(element)
    return element
  }

  const markDecorated = (element: HTMLElement, attribute: string): void => {
    element.setAttribute(attribute, '')
    decorated.add(element)
  }

  // Palette. overrideTokens rather than register(): a registered third-party
  // theme id does not cross dsh's built-in settings schema and so would not
  // survive a restart, whereas an override layer stacks over whichever
  // light/dark the user actually has persisted.
  guard('palette', () => {
    removeTokens = ctx.theme.overrideTokens(MANIFEST.packageName, MANIFEST.tokens)
  })

  // Shared structure first, then the theme's optional elaboration on top.
  // Unminified and unhashed on purpose: when this breaks, it has to be
  // readable in devtools.
  guard('structure', () => {
    createOwnedStyle('structure').textContent = STRUCTURE
  })
  guard('stylesheet', () => {
    if (MANIFEST.css.trim() === '') return
    createOwnedStyle('theme').textContent = MANIFEST.css
  })

  // The variable sheet carries everything continuous. cssRules[0] is the
  // single body rule every write below targets.
  const varSheet = createOwnedStyle('variables')
  varSheet.sheet?.insertRule(`body[${skinAttribute}='${MANIFEST.id}'] {}`)
  const varRule = varSheet.sheet?.cssRules[0] as CSSStyleRule | undefined
  const setVar = (name: string, value: string): void => {
    varRule?.style.setProperty(name, value)
  }

  guard('art-sheet', () => {
    createOwnedStyle('art').textContent = artSheet(MANIFEST.id)
  })

  /**
   * Resolve the title-bar row height in viewport space. Measuring the sidebar
   * column's top is authoritative across all three shells: whatever the row
   * actually is — the WCO `env()`, the desktop 32px row, or a scaled window —
   * the column is the row directly beneath it, and `env()` cannot be read back
   * from script.
   */
  const syncTitlebarHeight = (): void => {
    const top = q('sidebarColumn')?.getBoundingClientRect().top ?? 0
    if (top > 0) {
      setVar('--skin-titlebar-height', `${top}px`)
      return
    }
    setVar(
      '--skin-titlebar-height',
      q('desktopFrame') === null ? '0px' : `${DESKTOP_TITLEBAR_HEIGHT_PX}px`,
    )
  }

  const roundPx = (value: number): string => `${Math.round(value * 100) / 100}px`

  /**
   * Project the sidebar column's width, or `null` when there is no column to
   * measure yet.
   *
   * Those two cases are not the same and must not be collapsed. A measured
   * zero means the app really has no sidebar, and the decorations should sit
   * flush against the viewport edge. `null` means the app has not mounted its
   * shell yet — writing zero for that publishes a measurement the engine does
   * not have, and the figures commit to it for as long as the app takes to
   * render. Leaving the var alone lets the :root initial value stand until a
   * real measurement replaces it.
   */
  const applySidebarWidth = (width: number | null): void => {
    if (width === null) return
    if (width <= 0) {
      setVar('--skin-sidebar-width', '0px')
      setVar('--skin-sidebar-swag-height', '54px')
      setVar('--skin-sidebar-mascot-width', '0px')
      body.dataset.skinSidebarSize = 'rail'
      body.dataset.skinSidebarCompact = ''
      return
    }
    setVar('--skin-sidebar-width', roundPx(width))
    setVar('--skin-sidebar-swag-height', roundPx(Math.min(94, Math.max(54, width * 0.2575))))
    setVar('--skin-sidebar-mascot-width', roundPx(Math.min(320, width * 0.82)))
    body.dataset.skinSidebarSize = width <= SIDEBAR_RAIL_MAX_PX
      ? 'rail'
      : width <= SIDEBAR_NARROW_MAX_PX ? 'narrow' : 'wide'
    if (width <= SIDEBAR_COMPACT_MAX_PX) body.dataset.skinSidebarCompact = ''
    else delete body.dataset.skinSidebarCompact
  }

  /** Mirror app state onto body attributes so the stylesheet stays declarative. */
  const syncProjectedState = (): void => {
    const set = (attribute: string, active: boolean): void => {
      body.toggleAttribute(attribute, active)
    }
    const conversation = q('activeConversation')
    set(STATE.conversationActive, conversation !== null)
    set(STATE.chatActive, conversation !== null && q('chatFlow', conversation) !== null)
    set(STATE.workspace, q('workspaceTablist') !== null)
    set(
      STATE.betterSidebarOpen,
      q('betterSidebar') !== null && !body.hasAttribute('data-dsh-sidebar-collapsed'),
    )
    set(STATE.cordisPanelOpen, q('cordisPanel') !== null)
    set(
      STATE.settingsOpen,
      document.querySelector(`${SELECTORS.settingsTrigger.selector}[aria-expanded='true']`) !== null,
    )
  }

  const decorateCharacterStage = (): void => {
    if (body.querySelector(`[${OWNER_ATTRIBUTE}][data-skin-chrome='character-stage']`) !== null) {
      return
    }
    const stage = createOwned('div', 'character-stage')
    for (const [side, src] of [
      ['left', MANIFEST.art.characterLeft],
      ['right', MANIFEST.art.characterRight],
    ] as const) {
      const figure = document.createElement('img')
      figure.dataset.skinCharacter = side
      figure.alt = ''
      figure.src = src
      stage.append(figure)
    }
    // Prepended, not z-indexed: the stage and the app root are positioned at
    // the same level, so document order decides who paints on top. First child
    // means the characters sit behind the UI without the engine having to
    // reason about the app's stacking contexts.
    body.prepend(stage)
  }

  const createSidebarCorners = (): HTMLDivElement => {
    const corners = createOwned('div', 'sidebar-corners')
    for (const position of ['top-left', 'top-right', 'bottom-right', 'bottom-left']) {
      const corner = document.createElement('span')
      corner.dataset.skinCorner = position
      corners.append(corner)
    }
    return corners
  }

  const decorateSidebar = (): void => {
    const sidebar = q('sidebarColumn')
    if (sidebar === null) return
    const root = q('sidebarRoot', sidebar)
    if (root === null) return

    // Re-derive the footer marking from scratch: the app remounts these rows.
    sidebar.querySelectorAll<HTMLElement>('[data-skin-sidebar-footer]').forEach((element) => {
      element.removeAttribute('data-skin-sidebar-footer')
    })
    const settingsSlot = q('settingsSlot', sidebar)
    if (settingsSlot !== null) {
      let footer = settingsSlot.parentElement
      while (footer !== null && footer !== sidebar) {
        if (footer.querySelector(SELECTORS.sidebarFooterAction.selector) !== null) {
          markDecorated(footer, 'data-skin-sidebar-footer')
          break
        }
        footer = footer.parentElement
      }
    }

    // Anchored on the column, not `root`: the wrapper measures 0x0 in this
    // build, so percentage offsets against it collapse to the page origin.
    if (sidebar.querySelector(`[data-skin-chrome='sidebar-corners']`) === null) {
      sidebar.prepend(createSidebarCorners())
    }
    if (sidebar.querySelector(`[data-skin-chrome='sidebar-mascot']`) === null) {
      const mascot = createOwned('img', 'sidebar-mascot')
      mascot.alt = ''
      mascot.src = MANIFEST.art.sidebarMascot
      sidebar.prepend(mascot)
    }
  }

  /**
   * Group the workspace tree: each expanded workspace row and the session rows
   * beneath it become one framed block. Rebuilt wholesale on every pass
   * because the app reorders these rows freely.
   */
  const decorateWorkspaceTree = (): void => {
    const sidebar = q('sidebarColumn')
    if (sidebar === null) return

    sidebar.querySelectorAll<HTMLElement>(DECORATED.map(a => `[${a}]`).join(', '))
      .forEach((element) => {
        for (const attribute of DECORATED) {
          if (attribute !== 'data-skin-sidebar-footer') element.removeAttribute(attribute)
        }
      })

    for (const tree of qa('tree', sidebar)) {
      const rows = qa('treeItem', tree)
      if (tree.matches(SELECTORS.flatList.selector)
        && !rows.some(row => row.hasAttribute('aria-expanded'))) {
        rows.filter(row => row.hasAttribute('aria-selected')).forEach((row) => {
          markDecorated(row, 'data-skin-session-row')
          markDecorated(row, 'data-skin-session-flat')
        })
        continue
      }

      let workspaceRow: HTMLElement | undefined
      let sessionRows: HTMLElement[] = []
      const closeGroup = (): void => {
        if (workspaceRow === undefined) return
        markDecorated(workspaceRow, 'data-skin-workspace-row')
        if (workspaceRow.parentElement !== null) {
          markDecorated(workspaceRow.parentElement, 'data-skin-workspace-group')
        }
        sessionRows.forEach(row => markDecorated(row, 'data-skin-session-row'))
        const first = sessionRows[0]
        const last = sessionRows.at(-1)
        if (first !== undefined) markDecorated(first, 'data-skin-session-first')
        if (last !== undefined) markDecorated(last, 'data-skin-session-last')
        const holdsCurrent = workspaceRow.getAttribute('aria-expanded') === 'true'
          && sessionRows.some(row => row.getAttribute('aria-selected') === 'true')
        if (holdsCurrent) markDecorated(workspaceRow, 'data-skin-workspace-active')
      }

      for (const row of rows) {
        if (row.hasAttribute('aria-expanded')) {
          closeGroup()
          workspaceRow = row
          sessionRows = []
        } else if (workspaceRow !== undefined && row.hasAttribute('aria-selected')) {
          sessionRows.push(row)
        }
      }
      closeGroup()
    }
  }

  const decorateTitlebar = (): void => {
    const titlebar = q('titlebar')
    if (titlebar === null) return
    if (titlebar.querySelector(`[data-skin-chrome='titlebar-brand']`) !== null) return
    const brand = createOwned('span', 'titlebar-brand')
    brand.innerHTML = MANIFEST.art.brandSvg
    titlebar.prepend(brand)
  }

  const decorateTrims = (): void => {
    if (body.querySelector(`[${OWNER_ATTRIBUTE}][data-skin-chrome='top-trim']`) === null) {
      const topTrim = createOwned('div', 'top-trim')
      for (const layer of ['landing', 'workspace']) {
        const element = document.createElement('div')
        element.dataset.skinTrimLayer = layer
        topTrim.append(element)
      }
      body.append(topTrim)
    }
    if (body.querySelector(`[${OWNER_ATTRIBUTE}][data-skin-chrome='bottom-trim']`) === null) {
      body.append(createOwned('div', 'bottom-trim'))
    }
  }

  const decorateFavicon = (): void => {
    const favicon = document.createElement('link')
    favicon.rel = 'icon'
    favicon.href = MANIFEST.art.favicon
    favicon.setAttribute(OWNER_ATTRIBUTE, MANIFEST.id)
    owned.add(favicon)
    document.head.append(favicon)
  }

  /*
   * The settings mask mounts inside a promoted sidebar descendant, and Chrome
   * can omit sibling composited layers from that backdrop sample. Seating a
   * copy of the corner frame immediately before the mask keeps the overlay
   * sampling the ornamental frame rather than a flat surface.
   */
  const syncSettingsBackdropFrame = (): void => {
    const expanded = document.querySelector(
      `${SELECTORS.settingsTrigger.selector}[aria-expanded='true']`,
    )
    const mask = expanded === null ? null : q('settingsMask')
    const overlay = mask?.parentElement ?? null
    if (overlay === null) {
      settingsBackdropFrame?.remove()
      return
    }
    if (settingsBackdropFrame === undefined) {
      settingsBackdropFrame = createSidebarCorners()
      settingsBackdropFrame.setAttribute('data-skin-settings-backdrop-frame', '')
    }
    if (settingsBackdropFrame.parentElement !== overlay) {
      overlay.insertBefore(settingsBackdropFrame, mask)
    }
  }

  const syncComposerMotion = (): void => {
    const phaseRoot = q('composerPhase')
    const next = phaseRoot?.dataset.phase
    if (next !== 'hero' && next !== 'active') return
    if (composerPhase !== undefined && composerPhase !== next) {
      body.dataset.skinComposerMotion = next === 'active' ? 'dock' : 'rise'
      if (composerMotionTimer !== undefined) clearTimeout(composerMotionTimer)
      composerMotionTimer = setTimeout(() => {
        delete body.dataset.skinComposerMotion
        composerMotionTimer = undefined
      }, COMPOSER_MOTION_MS)
    }
    composerPhase = next
  }

  const syncSystemChrome = (): void => {
    const meta = q<HTMLMetaElement>('themeColorMeta', document.head)
    if (meta === null) return
    if (meta !== themeColorMeta) {
      themeColorMeta = meta
      originalThemeColor = meta.getAttribute('content')
    }
    if (meta.content !== MANIFEST.systemChromeColor) meta.content = MANIFEST.systemChromeColor
  }

  const ensureSidebarObserved = (): void => {
    const sidebar = q('sidebarColumn')
    if (resizeObserver === undefined || sidebar === observedSidebar) return
    if (observedSidebar !== undefined) resizeObserver.unobserve(observedSidebar)
    const hadSidebar = observedSidebar !== undefined
    observedSidebar = sidebar ?? undefined
    if (sidebar !== null) resizeObserver.observe(sidebar)
    else if (hadSidebar) applySidebarWidth(0)
  }

  /** Everything that must survive the app remounting its shell. */
  const resync = (): void => {
    guard('system-chrome', syncSystemChrome)
    guard('character-stage', decorateCharacterStage)
    guard('trims', decorateTrims)
    guard('titlebar-brand', decorateTitlebar)
    guard('sidebar', decorateSidebar)
    guard('workspace-tree', decorateWorkspaceTree)
    guard('sidebar-observe', ensureSidebarObserved)
    guard('titlebar-height', syncTitlebarHeight)
  }

  if (typeof ResizeObserver !== 'undefined') {
    resizeObserver = new ResizeObserver((entries) => {
      const entry = entries.at(-1)
      if (entry === undefined) return
      applySidebarWidth(entry.contentRect.width)
      syncTitlebarHeight()
    })
  }

  onViewportResize = (): void => {
    resizingLease.acquire()
    if (resizeSettleTimer !== undefined) clearTimeout(resizeSettleTimer)
    resizeSettleTimer = setTimeout(() => {
      resizingLease.release()
      resizeSettleTimer = undefined
    }, VIEWPORT_RESIZE_SETTLE_MS)
  }
  window.addEventListener('resize', onViewportResize)

  /*
   * rc.6 can mount its wide search and its outside-click listener during the
   * rail button's own click. That same event then reaches document with the
   * detached rail button as its target and immediately collapses the field.
   * Re-enter the component through its wide search root after the slide has
   * mounted; newer builds keep the wide field open, so the rail-only origin
   * check makes this compatibility path inert there.
   */
  onDocumentClick = (event: MouseEvent): void => {
    const target = event.target instanceof Element
      ? event.target.closest<HTMLElement>(SELECTORS.searchButton.selector)
      : null
    const railSearch = target?.closest<HTMLElement>(SELECTORS.searchRoot.selector) ?? null
    if (target === null || railSearch === null
      || railSearch.querySelector(SELECTORS.searchInput.selector) !== null) return

    if (searchFocusFrame !== undefined) cancelAnimationFrame(searchFocusFrame)
    const startedAt = performance.now()
    const recover = (): void => {
      searchFocusFrame = undefined
      const sidebar = q('sidebarColumn')
      const input = sidebar === null ? null : q<HTMLInputElement>('searchInput', sidebar)
      const root = input?.closest<HTMLElement>(SELECTORS.searchRoot.selector) ?? null
      if (input !== null && root !== null) {
        root.click()
        input.focus({ preventScroll: true })
        return
      }
      if (performance.now() - startedAt < 500) searchFocusFrame = requestAnimationFrame(recover)
    }
    searchFocusFrame = requestAnimationFrame(recover)
  }
  document.addEventListener('click', onDocumentClick)

  skinLease.acquire()
  if (!hasAcceleratedWebGL()) lowPowerLease.acquire()

  themeColorObserver = new MutationObserver(() => {
    guard('system-chrome', syncSystemChrome)
  })
  themeColorObserver.observe(document.head, {
    attributes: true,
    attributeFilter: ['content'],
    childList: true,
    subtree: true,
  })

  guard('favicon', decorateFavicon)
  guard('title', () => {
    document.title = MANIFEST.title
  })
  resync()
  guard('projected-state', syncProjectedState)
  guard('composer-motion', syncComposerMotion)
  guard('settings-backdrop', syncSettingsBackdropFrame)
  guard('sidebar-width', () => {
    applySidebarWidth(q('sidebarColumn')?.getBoundingClientRect().width ?? null)
  })

  // One observer, narrow filter, fanning out to independent syncs. Skin-owned
  // nodes are ignored so decorating the DOM cannot schedule another pass over
  // our own insertion, and terminal output is skipped entirely.
  observer = new MutationObserver((records) => {
    let structureChanged = false
    let workspaceChanged = false
    let stateChanged = false
    let composerChanged = false
    let settingsChanged = false

    for (const record of records) {
      const target = record.target instanceof Element ? record.target : undefined
      if (target?.closest(SELECTORS.terminal.selector) != null) continue

      if (record.type === 'attributes') {
        const name = record.attributeName
        if (name === 'aria-expanded'
          && target?.closest(SELECTORS.settingsSlot.selector) != null) {
          settingsChanged = true
          stateChanged = true
        } else if ((name === 'aria-expanded' || name === 'aria-selected')
          && target?.closest(SELECTORS.sidebarColumn.selector) != null) {
          workspaceChanged = true
        }
        if (name === 'data-phase') composerChanged = true
        if (name === 'data-phase' || name === 'data-chat-flow' || name === 'data-slot'
          || name === 'data-dsh-better-sidebar' || name === 'data-dsh-sidebar-collapsed'
          || name === 'data-cordis-panel' || name === 'role') {
          stateChanged = true
        }
        continue
      }

      const appNodes = [...record.addedNodes, ...record.removedNodes].filter(
        node => node instanceof Element && !node.hasAttribute(OWNER_ATTRIBUTE),
      )
      if (appNodes.length === 0) continue
      structureChanged = true
      stateChanged = true
      composerChanged = true
      settingsChanged = true
    }

    if (stateChanged) guard('projected-state', syncProjectedState)
    if (structureChanged) resync()
    else if (workspaceChanged) guard('workspace-tree', decorateWorkspaceTree)
    if (composerChanged) guard('composer-motion', syncComposerMotion)
    if (settingsChanged) guard('settings-backdrop', syncSettingsBackdropFrame)
  })
  observer.observe(body, {
    attributes: true,
    attributeFilter: [
      'aria-expanded',
      'aria-selected',
      'data-chat-flow',
      'data-cordis-panel',
      'data-ds-dark-theme',
      'data-dsh-better-sidebar',
      'data-dsh-sidebar-collapsed',
      'data-phase',
      'data-slot',
      'role',
    ],
    childList: true,
    subtree: true,
  })

  reportBootHealth(MANIFEST.id)
}
