/**
 * THE selector table. Every DOM selector this skin uses lives here and nowhere
 * else.
 *
 * dsh is a dev preview and its markup churns. When a release breaks the skin,
 * the repair is expected to be an edit to one row of this table — so each row
 * carries enough context to make that edit without re-deriving what the
 * selector was for:
 *
 *   tier    `stable`  — a documented contract surface (data-*, role, aria-*).
 *                       Upstream treats these as API; they rarely move.
 *           `fragile` — matches hashed CSS-module class names. These WILL
 *                       break. Every one is a known, accepted liability.
 *   targets what the selector is supposed to find.
 *   breaks  what the user actually sees go wrong when it stops matching. This
 *           is the field that turns a console MISS into a decision about
 *           whether to fix it now or later.
 *
 * `window.__DSH_SKIN__.diagnose()` prints this table with live match counts,
 * so after a dsh bump you read off the dead rows instead of bisecting CSS.
 *
 * Rules for adding a row:
 *   1. Prefer a stable surface. Only reach for a class match when no
 *      data-attribute, role, or aria state identifies the element.
 *   2. Never inline a selector at a call site, even "just once".
 *   3. Write `breaks` for the person repairing this in six months.
 */

/** How much upstream churn a selector is expected to survive. */
export type SelectorTier = 'stable' | 'fragile'

/** How many matches a healthy page is expected to yield. */
export type SelectorArity =
  /** Exactly one; zero is a MISS worth reporting. */
  | 'one'
  /** Zero or one; absence is a legitimate app state, never a MISS. */
  | 'optional'
  /** Any number; zero is a MISS worth reporting. */
  | 'many'

/** One selector and the context needed to repair it later. */
export interface SelectorSpec {
  readonly selector: string
  readonly tier: SelectorTier
  readonly arity: SelectorArity
  readonly targets: string
  readonly breaks: string
}

/**
 * Verified against dsh 0.1.0-rc.7. `data-*`, `role` and `aria-*` selectors are
 * the product's own contract surfaces; `[class*=...]` selectors match hashed
 * CSS-module names and are the fragile set.
 */
export const SELECTORS = {
  themeColorMeta: {
    selector: 'meta[name="theme-color"]',
    tier: 'stable',
    arity: 'optional',
    targets: 'The OS window-chrome colour hint in <head>.',
    breaks: 'Window chrome keeps the stock DeepSeek colour. Cosmetic, and only '
      + 'visible in installed/desktop mode.',
  },

  sidebarColumn: {
    selector: ":is([data-pane='sidebar'], [class*='sidebarCol'])",
    tier: 'fragile',
    arity: 'optional',
    targets: 'The sidebar column, whose width and viewport-top the engine tracks.',
    breaks: 'Sidebar art stops following the drag handle, trims lose their left '
      + 'offset, and the title-bar height falls back to 0. The [data-pane] half '
      + 'is stable; if upstream keeps it, drop the class half rather than '
      + 'repairing it.',
  },

  sidebarRoot: {
    selector: ':scope > div',
    tier: 'stable',
    arity: 'optional',
    targets: 'The sidebar column\'s single child, which hosts the corner frame '
      + 'and the mascot. Resolved relative to the sidebar column.',
    breaks: 'Sidebar corner ornament and mascot are never inserted.',
  },

  titlebar: {
    selector: "[class*='titlebar']",
    tier: 'fragile',
    arity: 'optional',
    targets: 'The frameless title bar of the web-app overlay / desktop shell.',
    breaks: 'The theme wordmark is not placed. In a plain browser tab this '
      + "element legitimately does not exist, hence 'optional'.",
  },

  desktopFrame: {
    selector: "[class*='frame'][data-desktop]",
    tier: 'fragile',
    arity: 'optional',
    targets: 'The desktop shell frame, which uses a fixed 32px title-bar row.',
    breaks: 'Title-bar height loses its desktop fallback and reports 0, '
      + 'mispositioning top trim in the desktop app only.',
  },

  settingsSlot: {
    selector: "[data-slot='sidebar.settings']",
    tier: 'stable',
    arity: 'optional',
    targets: 'The settings entry in the sidebar footer.',
    breaks: 'The footer is not framed and the settings-open state never '
      + 'projects, so the settings overlay loses its backdrop frame.',
  },

  settingsTrigger: {
    selector: "[data-slot='sidebar.settings'] > :is(button, [role='button'])",
    tier: 'stable',
    arity: 'optional',
    targets: 'The settings button whose aria-expanded drives the open state.',
    breaks: 'data-skin-settings-open never sets; the settings overlay renders '
      + 'unframed.',
  },

  settingsMask: {
    selector: "[role='presentation'] > [class*='mask']",
    tier: 'fragile',
    arity: 'optional',
    targets: 'The settings overlay backdrop mask.',
    breaks: 'The overlay backdrop frame is not seated, so the settings panel '
      + 'samples a flat backdrop instead of the ornamental one.',
  },

  sidebarFooterAction: {
    selector: "[data-slot='sidebar.footer.action']",
    tier: 'stable',
    arity: 'optional',
    targets: 'A footer action, used to locate the footer container to frame.',
    breaks: 'The sidebar footer loses its framed treatment.',
  },

  activeConversation: {
    selector: "[data-phase='active']",
    tier: 'stable',
    arity: 'optional',
    targets: 'The conversation root once a session is active.',
    breaks: 'The bottom trim never retracts, so it overlaps the composer.',
  },

  chatFlow: {
    selector: '[data-chat-flow]',
    tier: 'stable',
    arity: 'optional',
    targets: 'The chat transcript, present only in conversation views.',
    breaks: 'The two figures never retreat toward the edges during chat.',
  },

  composerPhase: {
    selector: "[data-phase='hero'], [data-phase='active']",
    tier: 'stable',
    arity: 'optional',
    targets: 'The composer phase root; the hero→active transition drives motion.',
    breaks: 'The composer rise/dock animation does not play. Purely motion.',
  },

  workspaceTablist: {
    selector: "header [role='tablist']",
    tier: 'stable',
    arity: 'optional',
    targets: 'The workspace tab strip.',
    breaks: 'Workspace crest and ribbon never appear and the workspace state '
      + 'does not project.',
  },

  betterSidebar: {
    selector: '[data-dsh-better-sidebar]',
    tier: 'stable',
    arity: 'optional',
    targets: 'The dsh-better-sidebar workbench, mounted on body.',
    breaks: 'The workbench keeps stock surfaces instead of the theme palette.',
  },

  cordisPanel: {
    selector: '[data-cordis-panel]',
    tier: 'stable',
    arity: 'optional',
    targets: 'The Cordis plugin panel.',
    breaks: 'The panel keeps stock surfaces.',
  },

  terminal: {
    selector: '[data-dsh-better-sidebar] .xterm',
    tier: 'stable',
    arity: 'optional',
    targets: 'The embedded terminal, whose high-frequency mutations are ignored.',
    breaks: 'Terminal output would wake the observer on every frame — a '
      + 'performance regression, not a visual one.',
  },

  tree: {
    selector: "[role='tree']",
    tier: 'stable',
    arity: 'optional',
    targets: 'The sidebar workspace/session tree.',
    breaks: 'Workspace groups and session rows lose their grouped framing.',
  },

  treeItem: {
    selector: "[role='treeitem']",
    tier: 'stable',
    // 'optional', not 'many': a fresh install with no sessions yet has an
    // empty tree, and reporting that as a MISS would train the reader to
    // ignore the diagnostic table.
    arity: 'optional',
    targets: 'Rows within a tree: workspaces (aria-expanded) and sessions.',
    breaks: 'Row decoration is skipped; the tree renders unstyled.',
  },

  flatList: {
    selector: "[class*='flatList']",
    tier: 'fragile',
    arity: 'optional',
    targets: 'The flat (ungrouped) session list variant.',
    breaks: 'Flat lists get grouped-list framing, which looks wrong but stays '
      + 'usable.',
  },

  searchButton: {
    selector: "button[class*='searchButton']",
    tier: 'fragile',
    arity: 'optional',
    targets: 'The rail-mode search button.',
    breaks: 'The rc.6 rail-search focus recovery stops working; on affected '
      + 'builds the search field closes immediately on click.',
  },

  searchRoot: {
    selector: "[class*='search']",
    tier: 'fragile',
    arity: 'optional',
    targets: 'The search component root.',
    breaks: 'Same as searchButton — focus recovery only.',
  },

  searchInput: {
    selector: "input[class*='searchInput']",
    tier: 'fragile',
    arity: 'optional',
    targets: 'The wide search field.',
    breaks: 'Same as searchButton — focus recovery only.',
  },
} as const satisfies Record<string, SelectorSpec>

/** Every selector key, for typed lookups and diagnostics iteration. */
export type SelectorKey = keyof typeof SELECTORS
