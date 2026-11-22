package games.paperballoon.controller.data

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Runs the shared cases in tests/nearby-label.json — the iOS port runs the same file
 * (NearbyLabelTests.swift). Robolectric only for org.json, which reads the cases.
 */
@RunWith(RobolectricTestRunner::class)
class NearbyLabelTest {

  // tests/ is on the unit-test resource path (app/build.gradle.kts).
  private val cases = JSONObject(javaClass.getResource("/nearby-label.json")!!.readText()).getJSONArray("cases")

  @Test
  fun sanitizeLabel() {
    for (case in cases.objects()) {
      val input = case.getString("input")
      assertEquals(input, case.getString("label"), sanitizeLabel(input))
    }
  }

  private fun JSONArray.objects() = List(length()) { getJSONObject(it) }
}
