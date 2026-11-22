package games.paperballoon.controller.ui.legal

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Runs the shared cases in tests/legal-links.json — the iOS port runs the same file
 * (LegalLinksTests.swift). Robolectric for android.net.Uri, which the check parses with.
 */
@RunWith(RobolectricTestRunner::class)
class LegalLinksTest {

  // tests/ is on the unit-test resource path (app/build.gradle.kts).
  private val cases = JSONObject(javaClass.getResource("/legal-links.json")!!.readText()).getJSONArray("cases")

  @Test
  fun legalDocUrl() {
    for (case in cases.objects()) {
      val input = case.getString("input")
      assertEquals(input, input.takeIf { case.getBoolean("legal") }, LegalLinks.legalDocUrl(input))
    }
  }

  private fun JSONArray.objects() = List(length()) { getJSONObject(it) }
}
