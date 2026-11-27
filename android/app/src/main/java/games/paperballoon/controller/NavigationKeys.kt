package games.paperballoon.controller

import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

@Serializable data object Main : NavKey

@Serializable data object About : NavKey

@Serializable data object Licenses : NavKey

// A plain in-app web viewer for a hosted legal document (privacy / imprint). The
// URL is loaded read-only in a WebView; the app bar title is derived from the document
// (the two pages cross-link, each opening as its own screen), so it re-localizes with
// the device language.
@Serializable
data class WebDoc(val url: String) : NavKey

@Serializable
data class GameHost(
  val joinUrl: String,
  val title: String,
  // Domains (subdomains included) the in-game WebView may navigate to; everything
  // else is bounced to the browser. The launcher's own domain is always added by
  // the host screen. This is the trust boundary for relay-supplied URLs.
  val allowedHosts: List<String>,
  // Unique per join, and read by nothing: NavDisplay tells entries apart by the key's
  // toString(), so a re-scan of the room already open would otherwise get the old host
  // back, paused, in place of a fresh join.
  val joinId: String,
) : NavKey
