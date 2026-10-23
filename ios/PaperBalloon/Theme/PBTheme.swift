import SwiftUI
import UIKit

// MARK: - Hex color init

extension Color {
    /// Opaque sRGB color from a 0xRRGGBB literal.
    init(pbHex: UInt32) {
        self.init(
            .sRGB,
            red: Double((pbHex >> 16) & 0xFF) / 255.0,
            green: Double((pbHex >> 8) & 0xFF) / 255.0,
            blue: Double(pbHex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - Palette

/// The Paper Balloon design language (Couch-Games assets/theme.css ⇄ Android
/// theme/Color.kt + Theme.kt ⇄ this file) mapped onto Material 3 roles, plus the tokens
/// that have no M3 role; must stay value-identical to the Android theme, minus the
/// tonal-button roles only Android's FilledTonalButton reads and the solid card fill only
/// Android's game cards use. The app icon sets the
/// palette: a sunset on a sky. Warm paper by day, near-black with a hint of the night
/// sky's violet by night; ink and paper carry the structure and the game posters carry
/// the colour. From the language's rules: the sunset fills a screen's one primary button and nothing
/// else, cards are flat (glass on iOS 26), tags are quiet tints. Interactive controls
/// stay the platform's own. Members are `var` only so the copy helpers can mutate a
/// copy; `.light`/`.dark` are the sole instances handed out.
struct PBPalette: Equatable {
    var primary, onPrimary, primaryContainer, onPrimaryContainer: Color
    var secondary, onSecondary: Color
    var background, onBackground, surface, onSurface: Color
    var surfaceVariant, onSurfaceVariant, outline, outlineVariant: Color
    var surfaceContainerLowest, surfaceContainerLow, surfaceContainer, surfaceContainerHigh, surfaceContainerHighest, surfaceBright: Color
    var error, onError, inverseSurface, inverseOnSurface, scrim: Color
    /// The room and game cards' fill where Liquid Glass is unavailable (before iOS 26).
    var frosted: Color
    /// The ghost button's fill and 1.5pt line.
    var ghost, ghostLine: Color
    /// The Beta tag's amber tint and the ink on it.
    var betaTag, onBetaTag: Color

    static let light = PBPalette(
        primary: Color(pbHex: 0x2A2030),
        onPrimary: Color(pbHex: 0xFFFFFF),
        primaryContainer: Color(pbHex: 0xF8ECE6),
        onPrimaryContainer: Color(pbHex: 0x2A2030),
        secondary: Color(pbHex: 0x625B71),
        onSecondary: Color(pbHex: 0xFFFFFF),
        background: Color(pbHex: 0xFFF8F3),
        onBackground: Color(pbHex: 0x2A2030),
        surface: Color(pbHex: 0xFFF8F3),
        onSurface: Color(pbHex: 0x2A2030),
        surfaceVariant: Color(pbHex: 0xF0DED4),
        onSurfaceVariant: Color(pbHex: 0x5E4F66),
        outline: Color(pbHex: 0x8E8296),
        outlineVariant: Color(pbHex: 0xEEDDD3),
        surfaceContainerLowest: Color(pbHex: 0xFFFFFF),
        surfaceContainerLow: Color(pbHex: 0xFCF3EE),
        surfaceContainer: Color(pbHex: 0xF8ECE6),
        surfaceContainerHigh: Color(pbHex: 0xF4E6DE),
        surfaceContainerHighest: Color(pbHex: 0xF0DED4),
        surfaceBright: Color(pbHex: 0xFFF8F3),
        error: Color(pbHex: 0xB3261E),
        onError: Color(pbHex: 0xFFFFFF),
        inverseSurface: Color(pbHex: 0x313033),
        inverseOnSurface: Color(pbHex: 0xF4EFF4),
        scrim: Color(pbHex: 0x000000),
        frosted: Color.white.opacity(0.72),
        ghost: Color(pbHex: 0xFFFFFF),
        ghostLine: Color(pbHex: 0xDCC7BE),
        betaTag: Color(pbHex: 0xFCE3CC),
        onBetaTag: Color(pbHex: 0x7A3E00)
    )

    static let dark = PBPalette(
        primary: Color(pbHex: 0xF1EFEC),
        onPrimary: Color(pbHex: 0x2A2030),
        primaryContainer: Color(pbHex: 0x3A3246),
        onPrimaryContainer: Color(pbHex: 0xF1EFEC),
        secondary: Color(pbHex: 0xCCC2DC),
        onSecondary: Color(pbHex: 0x332D41),
        background: Color(pbHex: 0x141119),
        onBackground: Color(pbHex: 0xF1EFEC),
        surface: Color(pbHex: 0x141119),
        onSurface: Color(pbHex: 0xF1EFEC),
        surfaceVariant: Color(pbHex: 0x2C2635),
        onSurfaceVariant: Color(pbHex: 0xABA9B0),
        outline: Color(pbHex: 0x8D8798),
        outlineVariant: Color(pbHex: 0x342C40),
        surfaceContainerLowest: Color(pbHex: 0x0D0B11),
        surfaceContainerLow: Color(pbHex: 0x201A2A),
        surfaceContainer: Color(pbHex: 0x251F30),
        surfaceContainerHigh: Color(pbHex: 0x2A2435),
        surfaceContainerHighest: Color(pbHex: 0x2C2635),
        surfaceBright: Color(pbHex: 0x434147),
        error: Color(pbHex: 0xF2B8B5),
        onError: Color(pbHex: 0x601410),
        inverseSurface: Color(pbHex: 0xE6E1E5),
        inverseOnSurface: Color(pbHex: 0x313033),
        scrim: Color(pbHex: 0x000000),
        frosted: Color.white.opacity(0.10),
        ghost: Color.white.opacity(0.08),
        ghostLine: Color.white.opacity(0.18),
        betaTag: Color(pbHex: 0xFFC14D).opacity(0.14),
        onBetaTag: Color(pbHex: 0xFFC14D)
    )

    /// The fill of a screen's one primary button, top to bottom: white text holds
    /// 4.6:1 at both ends. Nothing else wears it.
    static let actionSunset = [Color(pbHex: 0xE0185F), Color(pbHex: 0xD83A1A)]

    /// The home sky (MainScreen's SkyBackdrop), fading into the background below: zenith
    /// then horizon, lilac over peach, by day; one flat night by dark.
    static let skyLight = [Color(pbHex: 0xE6DAF2), Color(pbHex: 0xFFE0CC)]
    static let skyDark = Color(pbHex: 0x1C1725)

    /// The fleet flying in the sky: the icon's balloon in four colours, top to bottom of
    /// the envelope. Sunset leads and is always the biggest; sea, gold and dusk follow.
    /// By night the sunset and the dusk brighten so they lift off the dark.
    static let fleetSunset = [Color(pbHex: 0xF2216A), Color(pbHex: 0xFA6A2C)]
    static let fleetSunsetNight = [Color(pbHex: 0xFF4F86), Color(pbHex: 0xFF9640)]
    static let fleetSea = [Color(pbHex: 0x0F8F9E), Color(pbHex: 0x3CC29A)]
    static let fleetGold = [Color(pbHex: 0xF07A00), Color(pbHex: 0xFFC23D)]
    static let fleetDusk = [Color(pbHex: 0x6A4CF0), Color(pbHex: 0xC062E8)]
    static let fleetDuskNight = [Color(pbHex: 0xA07CFF), Color(pbHex: 0xE48BF7)]

    /// Copy with primary = accent, onPrimary = contentColorOn(accent). (Game-host accent remap.)
    func withAccent(_ accent: Color) -> PBPalette {
        var p = self
        p.primary = accent
        p.onPrimary = contentColorOn(accent)
        return p
    }
}

// MARK: - Luminance / contrast

/// WCAG relative luminance of a color's sRGB components.
func relativeLuminance(_ color: Color) -> Double {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    let uiColor = UIColor(color)
    if !uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
        // Not an RGB-compatible color space — convert via CGColor to sRGB.
        guard
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let converted = uiColor.cgColor.converted(to: space, intent: .defaultIntent, options: nil),
            let components = converted.components, components.count >= 3
        else { return 0 }
        r = components[0]
        g = components[1]
        b = components[2]
    }
    func linearize(_ c: CGFloat) -> Double {
        let v = min(max(Double(c), 0), 1)
        return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
}

/// Black or white over an arbitrary background, whichever wins on WCAG contrast.
/// A naive luminance > 0.5 split picks white on saturated mid-tones (a coral like
/// #FF6B6B sits at ~0.33) even though black reads far better there — the real
/// black/white crossover is at luminance ≈ 0.179, so compare the two contrasts.
func contentColorOn(_ color: Color) -> Color {
    let l = relativeLuminance(color)
    let blackContrast = (l + 0.05) / 0.05   // black L = 0
    let whiteContrast = 1.05 / (l + 0.05)   // white L = 1
    return blackContrast >= whiteContrast ? .black : .white
}

// MARK: - Environment

private struct PBPaletteKey: EnvironmentKey {
    static let defaultValue = PBPalette.light
}

extension EnvironmentValues {
    var pbPalette: PBPalette {
        get { self[PBPaletteKey.self] }
        set { self[PBPaletteKey.self] = newValue }
    }
}

private struct PBThemedModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let palette: PBPalette = colorScheme == .dark ? .dark : .light
        content
            .environment(\.pbPalette, palette)
            // Ink chrome accent for every system control (buttons, alerts, cursors);
            // the sunset is applied per-CTA, never as the global tint.
            .tint(palette.primary)
    }
}

extension View {
    /// Injects `\.pbPalette` from the current system color scheme. Applied once at RootView.
    func pbThemed() -> some View {
        modifier(PBThemedModifier())
    }
}

// MARK: - Typography (Dynamic Type text styles; M3-role names kept at call sites)

extension Font {
    static let pbTitleMedium = Font.headline
    static let pbBodyLarge = Font.body
    static let pbBodyMedium = Font.subheadline
    static let pbLabelLarge = Font.subheadline.weight(.medium)
    static let pbLabelMedium = Font.footnote.weight(.medium)
}
