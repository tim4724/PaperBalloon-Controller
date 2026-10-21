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

/// The paperballoon.games design tokens (Couch-Games assets/theme.css) mapped onto
/// Material 3 roles, plus the site card token that has no M3 role; must stay
/// value-identical to the Android theme (android theme/Color.kt + Theme.kt), minus the
/// tonal-button roles only Android's FilledTonalButton reads. Faintly warm paper light,
/// violet-tinted near-black dark; large fills use only the palest surface steps (the
/// deep ones read muddy at card size). From the site's rules: coral fills a screen's one
/// primary button and nothing else, and cards are flat with a hairline border.
/// Interactive controls stay the platform's own (the secondary button is the system
/// bordered button). Members are `var` only so the copy helpers can mutate a copy;
/// `.light`/`.dark` are the sole instances handed out.
struct PBPalette: Equatable {
    var primary, onPrimary, primaryContainer, onPrimaryContainer: Color
    var secondary, onSecondary: Color
    var background, onBackground, surface, onSurface: Color
    var surfaceVariant, onSurfaceVariant, outline, outlineVariant: Color
    var surfaceContainerLowest, surfaceContainerLow, surfaceContainer, surfaceContainerHigh, surfaceContainerHighest, surfaceBright: Color
    var error, onError, inverseSurface, inverseOnSurface, scrim: Color
    /// Site --card.
    var card: Color

    static let light = PBPalette(
        primary: Color(pbHex: 0x26242C),
        onPrimary: Color(pbHex: 0xFFFFFF),
        primaryContainer: Color(pbHex: 0xE7E4DF),
        onPrimaryContainer: Color(pbHex: 0x26242C),
        secondary: Color(pbHex: 0x625B71),
        onSecondary: Color(pbHex: 0xFFFFFF),
        background: Color(pbHex: 0xFAF9F7),
        onBackground: Color(pbHex: 0x1C1B1F),
        surface: Color(pbHex: 0xFAF9F7),
        onSurface: Color(pbHex: 0x1C1B1F),
        surfaceVariant: Color(pbHex: 0xE7E4DF),
        onSurfaceVariant: Color(pbHex: 0x5E5A66),
        outline: Color(pbHex: 0x77717F),
        outlineVariant: Color(pbHex: 0xDCD9D3),
        surfaceContainerLowest: Color(pbHex: 0xFFFFFF),
        surfaceContainerLow: Color(pbHex: 0xF7F5F2),
        surfaceContainer: Color(pbHex: 0xF2F0EC),
        surfaceContainerHigh: Color(pbHex: 0xEFEDEA),
        surfaceContainerHighest: Color(pbHex: 0xE7E4DF),
        surfaceBright: Color(pbHex: 0xFAF9F7),
        error: Color(pbHex: 0xB3261E),
        onError: Color(pbHex: 0xFFFFFF),
        inverseSurface: Color(pbHex: 0x313033),
        inverseOnSurface: Color(pbHex: 0xF4EFF4),
        scrim: Color(pbHex: 0x000000),
        card: Color(pbHex: 0xFFFFFF)
    )

    static let dark = PBPalette(
        primary: Color(pbHex: 0xF1EFEC),
        onPrimary: Color(pbHex: 0x26242C),
        primaryContainer: Color(pbHex: 0x3D3849),
        onPrimaryContainer: Color(pbHex: 0xF1EFEC),
        secondary: Color(pbHex: 0xCCC2DC),
        onSecondary: Color(pbHex: 0x332D41),
        background: Color(pbHex: 0x110F17),
        onBackground: Color(pbHex: 0xE6E1E5),
        surface: Color(pbHex: 0x110F17),
        onSurface: Color(pbHex: 0xE6E1E5),
        surfaceVariant: Color(pbHex: 0x332F3F),
        onSurfaceVariant: Color(pbHex: 0xA8A3B1),
        outline: Color(pbHex: 0x8D8798),
        outlineVariant: Color(pbHex: 0x2F2B3A),
        surfaceContainerLowest: Color(pbHex: 0x0B0A10),
        surfaceContainerLow: Color(pbHex: 0x1C1A24),
        surfaceContainer: Color(pbHex: 0x211E2B),
        surfaceContainerHigh: Color(pbHex: 0x2A2735),
        surfaceContainerHighest: Color(pbHex: 0x332F3F),
        surfaceBright: Color(pbHex: 0x413F45),
        error: Color(pbHex: 0xF2B8B5),
        onError: Color(pbHex: 0x601410),
        inverseSurface: Color(pbHex: 0xE6E1E5),
        inverseOnSurface: Color(pbHex: 0x313033),
        scrim: Color(pbHex: 0x000000),
        card: Color(pbHex: 0x1C1A24)
    )

    /// Site --action-solid: the fill of a screen's one primary button, behind a white
    /// label (4.6:1, AA). Nothing else is coral.
    static let actionCoral = Color(pbHex: 0xD63C43)

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
            // coral is applied per-CTA, never as the global tint.
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
