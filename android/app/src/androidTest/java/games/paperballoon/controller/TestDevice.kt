package games.paperballoon.controller

import android.content.Intent
import android.os.Build
import android.os.ParcelFileDescriptor
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.core.net.toUri
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import games.paperballoon.controller.data.Profile
import games.paperballoon.controller.data.ProfileStore
import games.paperballoon.controller.data.setNearbyOptedIn
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.json.JSONObject
import org.json.JSONTokener
import org.junit.Assert.assertTrue

/** The profile name every UI test runs under. */
internal const val PLAYER_NAME = "Alex"

/**
 * The contract test controller (the site repo's controller-test.html). Any build reaches the
 * deployed page through this App Link (the site repo's README, "Reaching it from the app"):
 * the 6-character path is what the intent filter claims.
 */
internal const val CONTRACT_PAGE = "https://test.paperballoon.games/PBTEST"

private const val PAGE_LOAD_TIMEOUT = 30_000L

/** Opens [CONTRACT_PAGE] the way an App Link does and runs [body] once its script is up. */
internal fun ComposeTestRule.inContractPage(body: (ActivityScenario<MainActivity>) -> Unit) {
  val context = InstrumentationRegistry.getInstrumentation().targetContext
  val intent = Intent(Intent.ACTION_VIEW, CONTRACT_PAGE.toUri(), context, MainActivity::class.java)
  ActivityScenario.launch<MainActivity>(intent).use { scenario ->
    waitUntil(PAGE_LOAD_TIMEOUT) {
      scenario.evalJs("document.querySelector('#mode')?.textContent ?? null") == "launcher shell"
    }
    body(scenario)
  }
}

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

/** Evaluates [script] in the game host's page; its JSON result, or null when no game is open. */
internal fun ActivityScenario<MainActivity>.evalJs(script: String): Any? {
  val done = CountDownLatch(1)
  var result: String? = null
  onActivity { activity ->
    val webView = activity.window.decorView.findWebView()
    if (webView == null) {
      done.countDown()
    } else {
      webView.evaluateJavascript(script) {
        result = it
        done.countDown()
      }
    }
  }
  assertTrue("no answer from the page: $script", done.await(10, TimeUnit.SECONDS))
  return result?.let { JSONTokener(it).nextValue() }?.takeUnless { it == JSONObject.NULL }
}

/** The game host's WebView in this view tree, or null while no game is open. */
internal fun View.findWebView(): WebView? = when (this) {
  is WebView -> this
  is ViewGroup -> (0 until childCount).firstNotNullOfOrNull { getChildAt(it).findWebView() }
  else -> null
}
