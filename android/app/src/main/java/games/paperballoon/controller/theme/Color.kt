package games.paperballoon.controller.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance

// The Paper Balloon design language (Couch-Games assets/theme.css ⇄ this file ⇄ iOS
// PBTheme.swift) mapped onto M3 roles. The app icon sets the palette: a sunset on a sky.
// By day the home sky is lilac over peach, fading into warm paper; by night the ground is
// near-black with a hint of violet. Ink and paper carry the structure and the game
// posters carry the colour. From the language's rules: the sunset fills a screen's one
// primary button and nothing else, cards are glass, tags are quiet tints, and the
// fleet's four colours go on the balloons and nowhere else. Interactive controls stay the
// platform's own (the secondary button is M3's tonal button). Container roles the
// language doesn't name are steps between its paper, panel and chip.
val PrimaryLight = Color(0xFF2A2030) // ink
val OnPrimaryLight = Color(0xFFFFFFFF)
val PrimaryContainerLight = Color(0xFFF8ECE6) // panel
val OnPrimaryContainerLight = Color(0xFF2A2030)

val PrimaryDark = Color(0xFFF1EFEC)
val OnPrimaryDark = Color(0xFF2A2030)
val PrimaryContainerDark = Color(0xFF3A3246)
val OnPrimaryContainerDark = Color(0xFFF1EFEC)

// Tonal-button fill: the paper blended a step toward the ink, NOT the chip tint — a
// peach fill reads as a tag, not a button.
val SecondaryContainerLight = Color(0xFFE1DAD8)
val OnSecondaryContainerLight = Color(0xFF2A2030)
val SurfaceVariantLight = Color(0xFFF0DED4) // chip
val OnSurfaceVariantLight = Color(0xFF5E4F66) // muted
val OutlineLight = Color(0xFF8E8296)
val OutlineVariantLight = Color(0xFFEEDDD3) // line

val SecondaryContainerDark = Color(0xFF44404F) // a step above the sheets' lilac glass
val OnSecondaryContainerDark = Color(0xFFF1EFEC)
val SurfaceVariantDark = Color(0xFF2C2635) // chip
val OnSurfaceVariantDark = Color(0xFFABA9B0) // muted
val OutlineDark = Color(0xFF8D8798)
val OutlineVariantDark = Color(0xFF342C40) // line

// Warm paper by day, near-black with a hint of the night sky's violet by night. res/values[-night]/colors.xml
// carries the same values for the launch window.
val SurfaceLightBase = Color(0xFFFFF8F3)
val SurfaceDarkBase = Color(0xFF141119)
val OnSurfaceLight = Color(0xFF2A2030) // ink
val OnSurfaceDark = Color(0xFFF1EFEC)

// The fill of a screen's one primary button, top to bottom: white text holds 4.6:1 at
// both ends. Nothing else wears it.
val ActionSunset = listOf(Color(0xFFE0185F), Color(0xFFD83A1A))

// The home sky (MainScreen's SkyBackdrop), fading into the background below: zenith then
// horizon, lilac over peach, by day; by night the afterglow in the ground's own hue, darker
// up high, then a faint rose at the horizon only a touch lighter than the ground.
val SkyLight = listOf(Color(0xFFE6DAF2), Color(0xFFFFE0CC))
val SkyNight = listOf(Color(0xFF0C0A12), Color(0xFF16111E), Color(0xFF21141F))

// The fleet flying in the sky: the icon's balloon in four colours, top to bottom of the
// envelope. Sunset leads and is always the biggest; sea, gold and dusk follow. By night
// the sunset and the dusk brighten so they lift off the dark.
val FleetSunset = listOf(Color(0xFFF2216A), Color(0xFFFA6A2C))
val FleetSunsetNight = listOf(Color(0xFFFF4F86), Color(0xFFFF9640))
val FleetSea = listOf(Color(0xFF0F8F9E), Color(0xFF3CC29A))
val FleetGold = listOf(Color(0xFFF07A00), Color(0xFFFFC23D))
val FleetDusk = listOf(Color(0xFF6A4CF0), Color(0xFFC062E8))
val FleetDuskNight = listOf(Color(0xFFA07CFF), Color(0xFFE48BF7))

// Per-scheme tokens with no M3 role: see the ColorScheme extensions in Theme.kt.
// The cards' glass, top to bottom: white easing into the paper by day, white mixed into
// the ground by night; its rim lit along the top (stops at 0, 30% and 100%).
internal val GlassLight = listOf(Color(0xFFFFFFFF), Color(0xFFFFFCFA))
internal val GlassRimLight = listOf(Color(0xFFFFFFFF), Color(0xFFEEDDD3), Color(0xFFD9C3B7))
internal val GlassDark = listOf(Color(0xFF242229), Color(0xFF1C1921))
internal val GlassRimDark = listOf(Color(0xFF353239), Color(0xFF242229), Color(0xFF1D1B22))
// Sheets wear the cards' glass; by night with a 10% wash of iOS's lilac (B4A3E6) over it.
internal val SheetGlassDark = listOf(Color(0xFF322F3C), Color(0xFF2B2735))
// Chips over the sky: frosted white.
internal val FrostedLight = Color(0xB8FFFFFF)
internal val FrostedDark = Color(0x24FFFFFF)
// The ghost button: paper with a 1.5dp line.
internal val GhostLight = Color(0xFFFFFFFF)
internal val GhostLineLight = Color(0xFFDCC7BE)
internal val GhostDark = Color(0x1FFFFFFF)
internal val GhostLineDark = Color(0x38FFFFFF)
// The Beta tag's amber tint and the ink on it.
internal val BetaTagLight = Color(0xFFFCE3CC)
internal val OnBetaTagLight = Color(0xFF7A3E00)
internal val BetaTagDark = Color(0x24FFC14D)
internal val OnBetaTagDark = Color(0xFFFFC14D)

/**
 * Black or white over [color], whichever wins on WCAG contrast — accents and
 * game-supplied colors arrive without a paired "on" color. A naive luminance > 0.5
 * split picks white on saturated mid-tones (a coral like #FF6B6B sits at ~0.33) even
 * though black reads far better there; the real black/white crossover is at luminance
 * ≈ 0.179, so compare the two contrasts instead.
 */
fun contentColorOn(color: Color): Color {
  val l = color.luminance()
  val blackContrast = (l + 0.05f) / 0.05f   // black L = 0
  val whiteContrast = 1.05f / (l + 0.05f)   // white L = 1
  return if (blackContrast >= whiteContrast) Color.Black else Color.White
}
