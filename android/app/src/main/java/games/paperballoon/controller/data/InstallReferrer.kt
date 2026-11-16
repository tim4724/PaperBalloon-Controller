package games.paperballoon.controller.data

import android.content.Context
import androidx.core.content.edit
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener

/**
 * CONTRACT.md §13: a game page's Google Play link carries its join URL as the install
 * referrer, so the first launch after that install joins the room the player came from.
 * Asked once per install: Play keeps the referrer readable for 90 days, and an existing
 * install updating to this build must not act on whatever it was installed from.
 */
object InstallReferrer {
  // Deliberately not in backup_rules.xml / data_extraction_rules.xml: a restored flag
  // would skip the check on the new device's fresh install.
  private const val PREFS = "pb_install_referrer"
  private const val KEY_CHECKED = "checked"

  /** Calls [onJoinLink] on the main thread with the referrer's join link, if it has one. */
  fun check(context: Context, onJoinLink: (String) -> Unit) {
    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    if (prefs.getBoolean(KEY_CHECKED, false)) return
    val client = InstallReferrerClient.newBuilder(context.applicationContext).build()
    // Some devices refuse the bind with a SecurityException instead of a response code.
    runCatching {
      client.startConnection(object : InstallReferrerStateListener {
        override fun onInstallReferrerSetupFinished(responseCode: Int) {
          // Any answer settles it: a sideload or a missing Play Store won't change on retry.
          prefs.edit { putBoolean(KEY_CHECKED, true) }
          if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
            runCatching { client.installReferrer }.getOrNull()
              ?.let { referrerJoinLink(it.installReferrer, it.installBeginTimestampSeconds, System.currentTimeMillis() / 1000) }
              ?.let(onJoinLink)
          }
          client.endConnection()
        }

        // The Play Store dropped the connection before answering; the next launch asks again.
        override fun onInstallReferrerServiceDisconnected() {}
      })
    }
  }
}

/** Long enough for a slow download, short enough that a first open days later doesn't
 * land on a room that has long closed. */
private const val REFERRER_MAX_AGE_SECONDS = 30 * 60L

/**
 * The referrer as a link to join, or null. An install from anywhere but a game page gets
 * Play's own `utm_source=…` string, which is no link. A link is still untrusted: it goes
 * through resolveJoin's host allow-list like a scanned one.
 */
internal fun referrerJoinLink(referrer: String?, installBeginSeconds: Long, nowSeconds: Long): String? =
  referrer?.takeIf { it.startsWith("https://") && nowSeconds - installBeginSeconds <= REFERRER_MAX_AGE_SECONDS }
