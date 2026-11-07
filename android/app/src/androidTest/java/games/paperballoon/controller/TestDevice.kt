package games.paperballoon.controller

import android.os.Build
import android.os.ParcelFileDescriptor
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.test.platform.app.InstrumentationRegistry
import games.paperballoon.controller.data.Profile
import games.paperballoon.controller.data.ProfileStore
import games.paperballoon.controller.data.setNearbyOptedIn

/** The profile name every UI test runs under. */
internal const val PLAYER_NAME = "Alex"

/**
 * Puts the device where the UI tests expect it, BEFORE the activity starts: [PLAYER_NAME] as
 * the profile name (first launch would mint a random one), and every one-time ask a fresh
 * device would show already answered.
 */
internal fun seedDevice() {
  val context = InstrumentationRegistry.getInstrumentation().targetContext
  ProfileStore.save(context, Profile(PLAYER_NAME))
  // Already opted in to nearby discovery, so home shows "Searching for rooms…" rather
  // than the one-time Local Network ask: the stored opt-in below API 37, the permission
  // grant from 37 on (see nearbyOptedIn).
  setNearbyOptedIn(context)
  if (Build.VERSION.SDK_INT >= 37) {
    shell("pm grant ${context.packageName} android.permission.ACCESS_LOCAL_NETWORK")
  }
  // A fresh device shows the one-time "Viewing full screen" education overlay the
  // first time an app hides the system bars (the in-game host does) — pre-confirm it.
  shell("settings put secure immersive_mode_confirmations confirmed")
}

/** Run a shell command with shell privileges and wait for it to finish. */
internal fun shell(cmd: String) {
  val pfd = InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand(cmd)
  ParcelFileDescriptor.AutoCloseInputStream(pfd).use { it.readBytes() }
}

/** The game host's WebView in this view tree, or null while no game is open. */
internal fun View.findWebView(): WebView? = when (this) {
  is WebView -> this
  is ViewGroup -> (0 until childCount).firstNotNullOfOrNull { getChildAt(it).findWebView() }
  else -> null
}
