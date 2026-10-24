import Observation
import SwiftUI

// MARK: - CodeSheet

/// A code entry in progress, shared by the sheet and the screen resolving its code: a
/// class the sheet observes, since a sheet's content doesn't track its presenter's state.
@MainActor @Observable final class CodeEntry: Identifiable {
    var loading = false
    var error: String?
}

/// Typing a room code: one box per character of the suite's code (six, case-sensitive
/// Base58), drawn over one invisible field, so the keyboard, paste and delete stay the
/// system's own. A character pops into its box; one a code can't hold (0, O, I, l or
/// anything else outside Base58) nudges the row instead. The sixth submits by itself,
/// and a code the relay can't place shakes the row and empties it, with the reason
/// under it. A pasted launcher link gives up its code. Android: CodeSheet.kt.
struct CodeSheet: View {
    let entry: CodeEntry
    let onSubmit: (String) -> Void

    /// The field's text, which shows a rejected edit for a frame before `accept` undoes it.
    @State private var code = ""
    /// What the boxes show: only what `accept` let through.
    @State private var shown = ""
    @State private var shakes = 0
    @State private var shakeWidth: CGFloat = 0
    @FocusState private var focused: Bool
    @Environment(\.pbPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter room code")
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.onSurface)
            boxes
            // The hint keeps its room under whatever stands in for it, so the sheet never
            // changes height.
            ZStack(alignment: .topLeading) {
                Text("Start a game on your TV or in your browser, then enter the code it shows.")
                    .opacity(entry.loading || entry.error != nil ? 0 : 1)
                if entry.loading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Joining…")
                    }
                } else if let error = entry.error {
                    Text(error).foregroundStyle(palette.error)
                }
            }
            .font(.pbBodyMedium)
            .foregroundStyle(palette.onSurfaceVariant)
            .animation(.easeOut(duration: 0.2), value: entry.error)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 28)
        .onAppear { focused = true }
        .onChange(of: entry.error) { _, error in
            guard error != nil else { return }
            shake(12)
            // A fresh start rather than hunting for the wrong character.
            shown = ""
            code = ""
        }
    }

    private var boxes: some View {
        HStack(spacing: 8) {
            ForEach(0..<PB.roomCodeLength, id: \.self) { i in
                CodeBox(
                    character: i < shown.count ? shown[shown.index(shown.startIndex, offsetBy: i)] : nil,
                    active: focused && !entry.loading && i == shown.count,
                    failed: entry.error != nil
                )
            }
        }
        // The field the boxes stand for: over them, so a tap focuses it and a long press
        // offers Paste, but drawn clear, caret and all.
        .overlay {
            TextField("", text: $code)
                .focused($focused)
                // A Base58 code is not a word: ASCII layout, no capitalization,
                // correction or predictions.
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.clear)
                .tint(.clear)
                .onChange(of: code) { _, new in accept(new) }
        }
        .keyframeAnimator(initialValue: 0.0, trigger: shakes) { row, x in
            row.offset(x: x)
        } keyframes: { _ in
            KeyframeTrack {
                for (i, x) in [-1.0, 1, -0.8, 0.8, -0.4, 0].enumerated() {
                    CubicKeyframe(x * shakeWidth, duration: i == 0 ? 0.05 : 0.07)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Room code"))
        .accessibilityValue(shown)
    }

    /// Keeps the field to what a code can be: characters outside Base58 and past the
    /// sixth are dropped, with a nudge. An insertion that is a whole code or a launcher
    /// link (a paste) replaces the field instead, without one.
    private func accept(_ new: String) {
        let old = shown
        // Not disabled while the code resolves: that would take the focus, and the
        // keyboard with it, just before an error asks for a correction.
        if entry.loading {
            if new != old { code = old }
            return
        }
        let inserted = new.hasPrefix(old) ? String(new.dropFirst(old.count)) : new
        let pasted = inserted.count > 1 ? originlessCode(inserted).flatMap { validRoomCode($0) ? $0 : nil } : nil
        let next = pasted ?? String(new.filter { PB.base58.contains($0) }.prefix(PB.roomCodeLength))
        if next != new {
            code = next
            if pasted == nil { shake(5) }
        }
        guard next != old else { return }
        shown = next
        // A changed code is a new attempt: the last one's error no longer applies.
        entry.error = nil
        if next.count == PB.roomCodeLength, old.count < PB.roomCodeLength { onSubmit(next) }
    }

    private func shake(_ width: CGFloat) {
        shakeWidth = width
        shakes += 1
    }
}

/// One character's box: it pops in when typed; the next box to fill carries a blinking
/// caret.
private struct CodeBox: View {
    let character: Character?
    let active: Bool
    let failed: Bool

    @Environment(\.pbPalette) private var palette

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(palette.surfaceContainerHighest)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(failed ? palette.error : active ? palette.primary : .clear, lineWidth: 2)
            }
            .frame(height: 58)
            .overlay {
                if let character {
                    Text(String(character))
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundStyle(palette.onSurface)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                } else if active {
                    PhaseAnimator([true, false]) { on in
                        Capsule()
                            .fill(palette.primary)
                            .frame(width: 2, height: 26)
                            .opacity(on ? 1 : 0)
                    } animation: { _ in .easeInOut(duration: 0.45) }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: character)
            .animation(.easeOut(duration: 0.15), value: active)
            .animation(.easeOut(duration: 0.15), value: failed)
    }
}
