package games.paperballoon.controller.ui.legal

import androidx.core.net.toUri
import games.paperballoon.controller.data.LAUNCHER_HOST

// Hosted legal pages, served on the launcher's own domain. Shown in-app via
// WebDocScreen (a plain WebView) so they stay reachable from within the app —
// which the German Impressum obligation (§5 DDG) requires, and GDPR expects for
// the privacy notice. Same operator hosts both the app and these pages.
object LegalLinks {
  const val PRIVACY_URL = "https://paperballoon.games/privacy"
  const val IMPRINT_URL = "https://paperballoon.games/imprint"

  // The launcher's public marketing site. Opened in the system browser (a full site,
  // not an in-app legal doc), but lives here since it's the same paperballoon.games root.
  const val WEBSITE_URL = "https://paperballoon.games"

  // The marketing site self-localizes, but opening it in the system browser drops the
  // app's chosen language. German gets an explicit /de/ deep link so the localized site
  // matches the app; other languages fall back to the root (which auto-detects).
  fun websiteUrl(language: String): String =
    if (language.equals("de", ignoreCase = true)) "$WEBSITE_URL/de/" else WEBSITE_URL

  // The two legal pages cross-link to each other, and the in-app viewer opens the
  // other as its own screen. These match a URL back to its document, for the title.
  fun isPrivacy(url: String): Boolean = matchesPath(url, "/privacy")

  fun isImprint(url: String): Boolean = matchesPath(url, "/imprint")

  private fun matchesPath(url: String, path: String): Boolean =
    url.substringBefore('?').substringBefore('#').trimEnd('/').endsWith(path)

  // A scanned QR payload, an incoming link and a link inside a legal page are arbitrary
  // content, and [isPrivacy]/[isImprint] match only the path. So before the doc viewer
  // (which trusts its URL: no allow-list) may load one, require the launcher apex over
  // https with no embedded credentials.
  // Returns the URL to open (locale variants like /en/privacy pass through as-is), or
  // null when it's not a legal page.
  fun legalDocUrl(raw: String): String? {
    val uri = runCatching { raw.toUri() }.getOrNull() ?: return null
    if (!"https".equals(uri.scheme, ignoreCase = true) || uri.userInfo != null) return null
    if (!uri.host.equals(LAUNCHER_HOST, ignoreCase = true)) return null
    return raw.takeIf { isPrivacy(it) || isImprint(it) }
  }
}
