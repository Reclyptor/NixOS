/**
 * Host loader entry for the browser-only skin plugin.
 *
 * Skins are presentation-only by upstream contract: they provide no service,
 * emit no Cordis event, and never touch a model request. All behaviour lives
 * in the client half.
 */
export function apply(): void {}
