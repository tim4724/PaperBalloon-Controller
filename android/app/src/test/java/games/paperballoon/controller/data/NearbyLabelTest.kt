package games.paperballoon.controller.data

import org.junit.Assert.assertEquals
import org.junit.Test

/** §8 instance name → card label. Mirrors NearbyLabelTests.swift. */
class NearbyLabelTest {

  @Test
  fun dropsDisplaySuffix() {
    assertEquals("Living Room", sanitizeLabel("Living Room · Paper Balloon"))
    // Longer than the cap on the wire, so this also pins stripping before capping.
    assertEquals("Living Room (2)", sanitizeLabel("Living Room · Paper Balloon (2)"))
    // A name without the suffix (tvOS, older displays) only gets its whitespace normalised.
    assertEquals("Living Room", sanitizeLabel("  Living   Room "))
    // Only a trailing suffix is the marker.
    assertEquals("Paper Balloon · Paper Ba", sanitizeLabel("Paper Balloon · Paper Balloon Club"))
  }
}
