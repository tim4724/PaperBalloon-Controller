package games.paperballoon.controller.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.unit.dp

private val DarkColors = darkColorScheme(
  primary = PrimaryDark,
  onPrimary = OnPrimaryDark,
  primaryContainer = PrimaryContainerDark,
  onPrimaryContainer = OnPrimaryContainerDark,
  secondaryContainer = SecondaryContainerDark,
  onSecondaryContainer = OnSecondaryContainerDark,
  surfaceVariant = SurfaceVariantDark,
  onSurfaceVariant = OnSurfaceVariantDark,
  outline = OutlineDark,
  outlineVariant = OutlineVariantDark,
  background = SurfaceDarkBase,
  onBackground = OnSurfaceDark,
  surface = SurfaceDarkBase,
  onSurface = OnSurfaceDark,
  surfaceDim = SurfaceDarkBase,
  surfaceBright = lerp(SurfaceDarkBase, Color.White, 0.20f),
  // Night steps: the TV black, the card, then the violet up to the chip.
  surfaceContainerLowest = Color(0xFF0D0B11),
  surfaceContainerLow = CardDark,
  surfaceContainer = Color(0xFF251F30),
  surfaceContainerHigh = Color(0xFF2A2435),
  surfaceContainerHighest = SurfaceVariantDark,
)

private val LightColors = lightColorScheme(
  primary = PrimaryLight,
  onPrimary = OnPrimaryLight,
  primaryContainer = PrimaryContainerLight,
  onPrimaryContainer = OnPrimaryContainerLight,
  secondaryContainer = SecondaryContainerLight,
  onSecondaryContainer = OnSecondaryContainerLight,
  surfaceVariant = SurfaceVariantLight,
  onSurfaceVariant = OnSurfaceVariantLight,
  outline = OutlineLight,
  outlineVariant = OutlineVariantLight,
  background = SurfaceLightBase,
  onBackground = OnSurfaceLight,
  surface = SurfaceLightBase,
  onSurface = OnSurfaceLight,
  // Explicit: the M3 default is lavender-white #FEF7FF, which clashes with paper
  // (and iOS mirrors this value).
  surfaceBright = SurfaceLightBase,
  // Day steps: white, then paper through the panel up to the chip.
  surfaceContainerLowest = Color.White,
  surfaceContainerLow = Color(0xFFFCF3EE),
  surfaceContainer = Color(0xFFF8ECE6),
  surfaceContainerHigh = Color(0xFFF4E6DE),
  surfaceContainerHighest = Color(0xFFF0DED4),
)

/**
 * Whether this is the night palette. Keyed on the scheme in force rather than the
 * system setting, so a forced palette gets the right tokens.
 */
val ColorScheme.isDark: Boolean
  get() = background.luminance() < 0.5f

/** The card fill: white on paper, one step up from the night ground. */
val ColorScheme.card: Color
  get() = if (isDark) CardDark else CardLight

/** Frosted white behind the chips that sit over the home sky. */
val ColorScheme.frosted: Color
  get() = if (isDark) FrostedDark else FrostedLight

/** The ghost button's fill and 1.5dp line. */
val ColorScheme.ghost: Color
  get() = if (isDark) GhostDark else GhostLight
val ColorScheme.ghostLine: Color
  get() = if (isDark) GhostLineDark else GhostLineLight

/** The Beta tag's amber tint and the ink on it. */
val ColorScheme.betaTag: Color
  get() = if (isDark) BetaTagDark else BetaTagLight
val ColorScheme.onBetaTag: Color
  get() = if (isDark) OnBetaTagDark else OnBetaTagLight

// The language's radii: 20 for cards, tiles and media, 28 for panels and sheets; buttons
// and fields are pills (M3's default button shape already).
private val AppShapes = Shapes(
  large = RoundedCornerShape(20.dp),
  extraLarge = RoundedCornerShape(28.dp),
)

/**
 * Standard Material 3 theming: follows the system light/dark setting; both
 * schemes are the brand palette (see Color.kt).
 */
@Composable
fun PaperBalloonTheme(
  darkTheme: Boolean = isSystemInDarkTheme(),
  content: @Composable () -> Unit,
) {
  MaterialTheme(
    colorScheme = if (darkTheme) DarkColors else LightColors,
    typography = Typography,
    shapes = AppShapes,
    content = content,
  )
}
