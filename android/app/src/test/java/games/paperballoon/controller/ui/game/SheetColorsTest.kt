package games.paperballoon.controller.ui.game

import androidx.compose.ui.graphics.Color
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Runs the shared cases in tests/sheet-colors.json — the iOS port runs the same file
 * (SheetColorsTests.swift). Robolectric only for org.json, which parseSheetColors reads with.
 */
@RunWith(RobolectricTestRunner::class)
class SheetColorsTest {

  // tests/ is on the unit-test resource path (app/build.gradle.kts).
  private val cases = JSONObject(javaClass.getResource("/sheet-colors.json")!!.readText())

  @Test
  fun parseSheetColors() {
    for (case in cases.getJSONArray("cases").objects()) {
      val input = case.getString("input")
      val expected = if (case.isNull("rgb")) null else case.getJSONArray("rgb").let { Color(it.getInt(0), it.getInt(1), it.getInt(2)) }
      // Surface and accent go through the same parse.
      val colors = parseSheetColors(JSONObject().put("surface", input).put("accent", input).toString())
      assertEquals("$input: surface", expected, colors.surface)
      assertEquals("$input: accent", expected, colors.accent)
    }
  }

  private fun JSONArray.objects() = List(length()) { getJSONObject(it) }
}
