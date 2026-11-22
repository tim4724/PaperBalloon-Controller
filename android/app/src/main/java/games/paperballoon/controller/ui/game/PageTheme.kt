package games.paperballoon.controller.ui.game

import androidx.compose.ui.graphics.Color
import org.json.JSONObject

/**
 * Evaluated when the hosting activity STOPs — home, app switch, lock (CONTRACT.md §7).
 *
 * A synthetic persisted `pagehide` tells the game to close its relay socket NOW,
 * so the display drops the player the moment they leave instead of whenever the
 * OS freezes the cached process (OEM/timing dependent — and on iOS never, which
 * is what made this deterministic dispatch necessary; Android mirrors it for
 * parity). No foreground counterpart: the engine fires the real
 * `visibilitychange` → visible on return, which is the game's reconnect trigger.
 */
internal const val DISPATCH_PAGE_HIDE_JS =
  "window.dispatchEvent(new PageTransitionEvent('pagehide', { persisted: true }));"

/**
 * Delivers a system back press to the page (CONTRACT.md §9), evaluated only in the
 * `page` back mode.
 *
 * Evaluates to `true` — the ONLY result that keeps the player in the game — when the
 * game both implements `back()` and returns a literal `true` from it. A missing
 * handler, a falsy/absent return (including a Promise, which is why §9 requires a
 * synchronous decision) or a throw all evaluate to `false`, and the launcher leaves.
 */
internal const val DELIVER_BACK_JS =
  "(() => { try { return window.PaperBalloon && typeof window.PaperBalloon.back === 'function' &&" +
    " window.PaperBalloon.back() === true; } catch (e) { return false; } })()"

/**
 * The launcher-injected observer for the page's `color-scheme` meta (CONTRACT.md §4),
 * evaluated after each page load. Pushes whether the page is dark through the
 * launcher-internal `__pbScheme` interface (see SchemeBridge) immediately and on every
 * change — head mutations via MutationObserver, plus system scheme flips (`light dark`
 * follows the system). Pushes are deduped. No meta reads as light, the web's own
 * default. Re-running on a document that already has the observer just re-pushes.
 * evaluateJavascript is exempt from the page's CSP, so `script-src 'self'` game origins
 * keep working.
 */
internal val WATCH_PAGE_SCHEME_JS = """
  (() => {
    if (window.__pbSchemePush) { window.__pbSchemePush(); return; }
    const systemDark = matchMedia('(prefers-color-scheme: dark)');
    let last;
    const push = () => {
      const meta = document.querySelector('meta[name="color-scheme"]');
      const schemes = (meta?.getAttribute('content') ?? '').toLowerCase().split(/\s+/);
      const dark = schemes.includes('dark') && (!schemes.includes('light') || systemDark.matches);
      if (dark === last) return;
      last = dark;
      window.__pbScheme?.changed(dark);
    };
    window.__pbSchemePush = push;
    new MutationObserver(push).observe(document.head, {
      childList: true, subtree: true, attributes: true, attributeFilter: ['content', 'name'],
    });
    systemDark.addEventListener('change', push);
    push();
  })()
""".trimIndent()

/** The page's own colors for the launcher's name sheet (CONTRACT.md §2). */
internal data class SheetColors(val surface: Color? = null, val accent: Color? = null)

/**
 * Read once, when the page opens the name sheet: `<meta name="theme-color">` (first one
 * whose `media` matches) for the surface, and the CSS `accent-color` of `<html>` for the
 * accent — `auto` (unset) reads as none. Both normalized to rgb() by computed style;
 * CSS.supports() first, because an invalid color would fall back to the inherited one.
 */
internal val READ_SHEET_COLORS_JS = """
  (() => {
    const rgb = (value) => {
      if (!value || !CSS.supports('color', value)) return null;
      const probe = document.createElement('div');
      probe.style.color = value;
      document.documentElement.appendChild(probe);
      const color = getComputedStyle(probe).color;
      probe.remove();
      return color;
    };
    const meta = [...document.querySelectorAll('meta[name="theme-color"]')]
      .find((m) => !m.getAttribute('media') || matchMedia(m.getAttribute('media')).matches);
    const accent = getComputedStyle(document.documentElement).accentColor;
    return { surface: rgb(meta?.getAttribute('content')), accent: accent === 'auto' ? null : rgb(accent) };
  })()
""".trimIndent()

// Computed styles serialize sRGB colors as rgb(r, g, b) / rgba(r, g, b, a).
// Wide-gamut serializations (color(display-p3 …), lab(…)) deliberately fail.
private val CSS_RGB = Regex("""rgba?\((\d{1,3}), (\d{1,3}), (\d{1,3})(?:, [0-9.]+)?\)""")

/** The script's result is untrusted page data: strict shape, fallback on anything odd. */
internal fun parseSheetColors(json: String?): SheetColors = runCatching {
  val obj = JSONObject(json.orEmpty())
  SheetColors(parseCssRgb(obj.optString("surface")), parseCssRgb(obj.optString("accent")))
}.getOrDefault(SheetColors())

private fun parseCssRgb(value: String): Color? {
  val match = CSS_RGB.matchEntire(value.trim()) ?: return null
  val (r, g, b) = match.destructured.toList().map { it.toInt() }
  if (r > 255 || g > 255 || b > 255) return null
  // Alpha is deliberately dropped: the sheet surface must be opaque.
  return Color(r, g, b)
}

/**
 * Document-start script, injected only while the local-network dialog is still to be
 * answered (see the gate in GameHostContent). Holds every
 * `RTCPeerConnection.setLocalDescription` — the call that starts candidate gathering, on
 * the offering and the answering side alike — asks the launcher for the permission on
 * the first one, and lets them all through on OPEN_LAN_GATE_JS. Once open, calls pass
 * straight through. Games see only a slower setLocalDescription.
 *
 * Top frame only: evaluateJavascript reaches no other, so an iframe's held call would
 * never be let through.
 */
internal val LAN_GATE_JS = """
  (() => {
    const lan = window.__pbLan;
    const pc = window.RTCPeerConnection && window.RTCPeerConnection.prototype;
    if (window !== window.top || !lan || !pc || window.__pbLanOpen) return;
    const setLocal = pc.setLocalDescription;
    let release;
    const gate = new Promise((resolve) => { release = resolve; });
    let asked = false;
    window.__pbLanOpen = () => release();
    pc.setLocalDescription = function (...args) {
      if (lan.isOpen()) return setLocal.apply(this, args);
      if (!asked) {
        asked = true;
        lan.ask();
      }
      return gate.then(() => setLocal.apply(this, args));
    };
  })();
""".trimIndent()

/** Lets LAN_GATE_JS's held calls through, evaluated once the dialog is answered. */
internal const val OPEN_LAN_GATE_JS = "window.__pbLanOpen && window.__pbLanOpen();"

/**
 * Evaluated when WebView reports a page start, right after the launcher has reset the
 * §9 back mode and re-armed §10. That report and the page's bridge calls travel by
 * different threads, so a page that asks in its first script can be heard BEFORE the
 * reset that was meant for its predecessor, and lose both. The new document says them
 * again; one that has asked nothing says nothing.
 */
internal const val RESEND_PAGE_MODES_JS = "window.__pbResendModes && window.__pbResendModes();"

/**
 * Document-start script: defines `window.PaperBalloonHost` (CONTRACT.md) over the raw
 * `__pbHost` and `__pbName` Java interfaces, for the two members a Java interface can't
 * express — a `name` property and an `editName()` that returns a Promise — and for the one
 * argument it can't take, `hapticComposition()`'s array of steps, flattened to a string.
 * Everything else passes straight through, so the Java bridge's own argument conversions
 * still apply. Every `editName()` reaches the launcher and gets its own Promise; the
 * launcher answers them in order through `__pbNameResult(name | null)`.
 *
 * It also keeps what this document last asked of §9 and §10, for [RESEND_PAGE_MODES_JS].
 */
internal val HOST_SHIM_JS = """
  (() => {
    const host = window.__pbHost;
    const names = window.__pbName;
    if (!host || !names || window.PaperBalloonHost) return;
    const waiting = [];
    window.__pbNameResult = (name) => {
      const done = waiting.shift();
      if (done) done(typeof name === 'string' ? name : null);
    };
    // A §12 sequence flattened to `primitive,scale,delay;…`; a non-array is nothing (not
    // the empty sequence's stop). The native side is authoritative and re-checks every
    // field — keep the step cap in step with GameHaptics.parseComposition. Non-numbers
    // become 0, as the typed bridge would.
    const hapticComposition = (steps) => {
      if (!Array.isArray(steps)) return;
      host.hapticSteps(steps.slice(0, 32).map((s) => {
        s = s || {};
        return String(s.primitive) + ',' + (typeof s.scale === 'number' ? s.scale : 0) +
          ',' + (typeof s.delay === 'number' ? s.delay : 0);
      }).join(';'));
    };
    // Boxed, so an argument of undefined still counts as asked.
    let backMode, orientation;
    window.__pbResendModes = () => {
      if (backMode) host.setBackMode(backMode[0]);
      if (orientation) host.setOrientation(orientation[0]);
    };
    window.PaperBalloonHost = {
      get name() { return names.getName(); },
      editName() {
        return new Promise((resolve) => {
          waiting.push(resolve);
          names.editName();
        });
      },
      gameEnded: (reason) => host.gameEnded(reason),
      leave: () => host.leave(),
      setBackMode: (mode) => { backMode = [mode]; host.setBackMode(mode); },
      setOrientation: (mode) => { orientation = [mode]; host.setOrientation(mode); },
      haptic: (primitive, scale) => host.haptic(primitive, scale),
      hapticComposition,
    };
  })();
""".trimIndent()
