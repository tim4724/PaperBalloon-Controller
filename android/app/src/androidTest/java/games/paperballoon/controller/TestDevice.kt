package games.paperballoon.controller

import android.content.ContentValues
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.core.net.toUri
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import games.paperballoon.controller.data.Profile
import games.paperballoon.controller.data.ProfileStore
import games.paperballoon.controller.data.setNearbyOptedIn
import java.io.File
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

/**
 * The clean status bar of a store screenshot: fixed clock, full battery and signal, no
 * notifications. A `cmd uimode night` flip knocks SystemUI out of demo mode, so apply it
 * after the theme.
 */
internal fun applyDemoStatusBar() {
  shell("settings put global sysui_demo_allowed 1")
  shell("am broadcast -a com.android.systemui.demo -e command enter")
  shell("am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false")
  shell("am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 -e fully true")
  shell("am broadcast -a com.android.systemui.demo -e command notifications -e visible false")
  shell("am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941")
  Thread.sleep(500)
}

/**
 * Deep-links (the App Link path) into a controller page and runs [body] once the
 * "Joining…" cover has faded — after the turn, for a [landscape] page, which asks for it
 * (CONTRACT §10) before its first paint. The shell fades the cover on WebView's
 * visual-state callback, so its absence means the page has been drawn, not merely loaded.
 */
internal fun ComposeTestRule.inGamePage(url: String, landscape: Boolean = false, body: () -> Unit) {
  val context = InstrumentationRegistry.getInstrumentation().targetContext
  val intent = Intent(Intent.ACTION_VIEW, url.toUri(), context, MainActivity::class.java)
  ActivityScenario.launch<MainActivity>(intent).use { scenario ->
    // "Joining %1$s…" localized prefix, title-independent.
    val joiningPrefix = context.getString(R.string.joining_game, "@@").substringBefore("@@")
    // The game host (its WebView), then the cover gone. Only its absence, never its
    // appearance: a page the WebView has cached can paint before the first check.
    waitUntil(timeoutMillis = 15_000) {
      var hosting = false
      scenario.onActivity { hosting = it.window.decorView.findWebView() != null }
      hosting
    }
    waitUntil(timeoutMillis = 30_000) {
      onAllNodes(hasText(joiningPrefix, substring = true)).fetchSemanticsNodes().isEmpty()
    }
    if (landscape) {
      waitUntil(timeoutMillis = 15_000) {
        var turned = false
        scenario.onActivity { turned = it.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE }
        turned
      }
    }
    body()
  }
}

/**
 * A full-device capture (system bars included, and sheets, which live in their own
 * windows) saved as `Pictures/<dir>/<name>.png` through MediaStore: shared storage needs no
 * permission and outlives the uninstall after the run, so `adb pull` collects it. Clear the
 * directory before a run, or MediaStore renames repeats "x (1).png".
 */
internal fun ComposeTestRule.screenshot(dir: String, name: String) {
  waitForIdle()
  Thread.sleep(400) // ripples, IME slide-in, window transitions
  val instrumentation = InstrumentationRegistry.getInstrumentation()
  val bitmap = requireNotNull(instrumentation.uiAutomation.takeScreenshot()) { "takeScreenshot returned null" }
  val context = instrumentation.targetContext
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
    val values = ContentValues().apply {
      put(MediaStore.Images.Media.DISPLAY_NAME, "$name.png")
      put(MediaStore.Images.Media.MIME_TYPE, "image/png")
      put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/$dir")
    }
    val resolver = context.contentResolver
    val uri = requireNotNull(resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)) {
      "MediaStore insert failed for $name"
    }
    resolver.openOutputStream(uri)!!.use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
  } else {
    // Pre-Q fallback (dev devices only — CI runs API 35): app-private files.
    val target = File(context.filesDir, dir).apply { mkdirs() }
    File(target, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
  }
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
