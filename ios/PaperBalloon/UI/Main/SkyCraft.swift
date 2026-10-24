import SwiftUI

/// What tows the hidden sky's "Made with ♥" banner, picked at random once a launch: the
/// blimp or the plane by day, the rocket or the saucer by night. Drawn like the fleet: one
/// silhouette over a fleet gradient, its panels parted by thin gaps.
enum SkyCraft: CaseIterable {
    case blimp, plane, rocket, saucer

    /// How fast it flies right, in points a second.
    var speed: CGFloat {
        switch self {
        case .blimp: 20
        case .plane: 34
        case .rocket: 44
        case .saucer: 26
        }
    }

    /// Its width in points; the height follows from the art's unit box.
    fileprivate var width: CGFloat {
        switch self {
        case .blimp: 64
        case .plane: 60
        case .rocket: 66
        case .saucer: 54
        }
    }

    /// The art's box: 100 units wide, nose to the right.
    fileprivate var unitHeight: CGFloat {
        switch self {
        case .blimp, .rocket: 40
        case .plane: 42
        case .saucer: 46
        }
    }

    var size: CGSize { CGSize(width: width, height: width * unitHeight / 100) }

    /// Where the rope ties on, as fractions of `size`. The craft tilts about it, so the
    /// rope stays on.
    fileprivate var tow: UnitPoint {
        switch self {
        case .blimp: UnitPoint(x: 0.14, y: 16.5 / 40)
        case .plane: UnitPoint(x: 0.16, y: 18 / 42)
        case .rocket: UnitPoint(x: 0.28, y: 0.5)
        case .saucer: UnitPoint(x: 0.03, y: 24 / 46)
        }
    }

    /// Whether it flies in the night sky, rather than by day.
    var night: Bool { self == .rocket || self == .saucer }

    var colors: [Color] {
        switch self {
        case .blimp: PBPalette.fleetDusk
        case .plane: PBPalette.fleetSunset
        case .saucer: PBPalette.fleetSea
        case .rocket: PBPalette.fleetGold
        }
    }

    /// Up and down, in points, `t` seconds into its flight: the whole tow rises and falls.
    func bob(_ t: TimeInterval) -> CGFloat {
        switch self {
        case .blimp: 3 * sin(t * 2 * .pi / 9)
        case .plane: 2 * sin(t * 2 * .pi / 4)
        case .rocket: 1 * sin(t * 2 * .pi / 0.7)
        case .saucer: 3 * sin(t * 2 * .pi / 2.5)
        }
    }

    /// The craft's own lean, about its tow point.
    func tilt(_ t: TimeInterval) -> Angle {
        switch self {
        case .blimp: .degrees(1.5 * sin(t * 2 * .pi / 9 + .pi / 2))
        case .plane: .degrees(2 * sin(t * 2 * .pi / 4 + .pi / 2))
        case .rocket: .zero
        case .saucer: .degrees(5 * sin(t * 2 * .pi / 1.7))
        }
    }
}

extension VerticalAlignment {
    private enum Tow: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
    }

    /// The rope's line: the banner's middle and the craft's tow point.
    fileprivate static let tow = VerticalAlignment(Tow.self)
}

/// A craft with the banner trailing behind it on its rope.
struct TowedBanner: View {
    let craft: SkyCraft
    /// Seconds into its flight, for its own motion.
    let t: TimeInterval

    @Environment(\.pbPalette) private var palette

    var body: some View {
        let size = craft.size
        HStack(alignment: .tow, spacing: 0) {
            Text("Made with ♥")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(PBPalette.fleetSunset[0])
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.white, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            // On to the tow point, under the craft.
            Rectangle()
                .fill(palette.onSurfaceVariant.opacity(0.6))
                .frame(width: 10 + craft.tow.x * size.width, height: 1)
            SkyCraftArt(craft: craft, t: t)
                .frame(width: size.width, height: size.height)
                .rotationEffect(craft.tilt(t), anchor: craft.tow)
                .alignmentGuide(VerticalAlignment.tow) { $0.height * craft.tow.y }
                .padding(.leading, -craft.tow.x * size.width)
        }
        .fixedSize()
    }
}

/// The craft alone: its silhouette over its gradient, and what moves on it — the
/// plane's propeller, the rocket's flames.
private struct SkyCraftArt: View {
    let craft: SkyCraft
    let t: TimeInterval

    var body: some View {
        let colors = craft.colors
        ZStack {
            switch craft {
            case .plane:
                // A blade seen edge-on as it turns: tall, then thin.
                UnitShape(height: craft.unitHeight, path: Path(ellipseIn: CGRect(x: 95, y: 4, width: 4, height: 34)))
                    .fill(colors[0].opacity(0.6))
                    .scaleEffect(x: 1, y: max(0.15, abs(cos(t * 2 * .pi * 4))), anchor: .center)
            case .rocket:
                // One flame for each engine, above and below the rope.
                UnitShape(height: craft.unitHeight, path: SkyCraft.rocketFlames)
                    .fill(LinearGradient(colors: [PBPalette.fleetGold[1], PBPalette.fleetSunset[1]],
                                         startPoint: .trailing, endPoint: .leading))
                    .scaleEffect(x: 0.8 + 0.12 * sin(t * 2 * .pi * 6) + 0.08 * sin(t * 2 * .pi * 11),
                                 y: 1, anchor: UnitPoint(x: 0.21, y: 0.5))
            default:
                EmptyView()
            }
            UnitShape(height: craft.unitHeight, path: craft.silhouette)
                .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
        }
    }
}

/// A path drawn in a box 100 units wide, scaled to fit.
private struct UnitShape: Shape {
    let height: CGFloat
    let path: Path

    func path(in rect: CGRect) -> Path {
        path.applying(CGAffineTransform(scaleX: rect.width / 100, y: rect.height / height)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}

private extension SkyCraft {
    /// The gaps between panels, in units: about the fleet's.
    static let gap: CGFloat = 2.4

    /// Cut once: path operations are costly, and a craft in view draws every frame.
    var silhouette: Path { Self.silhouettes[self]! }
    private static let silhouettes = Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.cutSilhouette()) })

    static let rocketFlames: Path = {
        var flames = Path()
        for y in [14.0, 26] {
            flames.move(to: CGPoint(x: 21, y: y - 2.6))
            flames.addQuadCurve(to: CGPoint(x: 3, y: y), control: CGPoint(x: 8, y: y - 3.2))
            flames.addQuadCurve(to: CGPoint(x: 21, y: y + 2.6), control: CGPoint(x: 8, y: y + 3.2))
            flames.closeSubpath()
        }
        return flames
    }()

    private func cutSilhouette() -> Path {
        switch self {
        case .blimp:
            let envelope = Path(ellipseIn: CGRect(x: 14, y: 3, width: 84, height: 27))
            let parts = [
                envelope,
                polygon((0, 1), (10, 1), (30, 10), (20, 15)),
                polygon((0, 32), (10, 32), (30, 23), (20, 18)),
                Path(roundedRect: CGRect(x: 46, y: 31, width: 22, height: 8), cornerRadius: 3),
            ]
            var seams = envelope
            for x in [38.0, 58, 78] {
                seams.move(to: CGPoint(x: x, y: 1))
                seams.addQuadCurve(to: CGPoint(x: x, y: 32), control: CGPoint(x: x + 7, y: 16.5))
            }
            seams.move(to: CGPoint(x: 14, y: 16.5))
            seams.addLine(to: CGPoint(x: 98, y: 16.5))
            let windows = [51.0, 57, 63].map { Path(ellipseIn: CGRect(x: $0 - 1.4, y: 33.6, width: 2.8, height: 2.8)) }
            return cut(parts, seams: seams, holes: windows)
        case .plane:
            var fuselage = Path()
            fuselage.move(to: CGPoint(x: 16, y: 15))
            fuselage.addLine(to: CGPoint(x: 78, y: 13))
            fuselage.addQuadCurve(to: CGPoint(x: 92, y: 21), control: CGPoint(x: 92, y: 13))
            fuselage.addQuadCurve(to: CGPoint(x: 78, y: 29), control: CGPoint(x: 92, y: 29))
            fuselage.addLine(to: CGPoint(x: 34, y: 28))
            fuselage.addLine(to: CGPoint(x: 16, y: 20))
            fuselage.closeSubpath()
            // A biplane: the lower wing along the fuselage's belly, the upper on struts.
            let lowerWing = Path(roundedRect: CGRect(x: 38, y: 25, width: 34, height: 5), cornerRadius: 2.5)
            let parts = [
                fuselage,
                lowerWing,
                Path(roundedRect: CGRect(x: 40, y: 3, width: 32, height: 5), cornerRadius: 2.5),
                Path(CGRect(x: 46, y: 7, width: 2.2, height: 8)),
                Path(CGRect(x: 63, y: 7, width: 2.2, height: 8)),
                polygon((8, 2), (17, 2), (32, 15), (16, 16)),
                Path(CGRect(x: 54.8, y: 29, width: 2.4, height: 5)),
                Path(ellipseIn: CGRect(x: 51.5, y: 33, width: 9, height: 9)),
            ]
            var seams = lowerWing
            seams.move(to: CGPoint(x: 36, y: 10))
            seams.addLine(to: CGPoint(x: 36, y: 30))
            seams.move(to: CGPoint(x: 82, y: 10))
            seams.addQuadCurve(to: CGPoint(x: 82, y: 32), control: CGPoint(x: 85, y: 21))
            let window = Path(roundedRect: CGRect(x: 68, y: 15.5, width: 9, height: 5), cornerRadius: 2)
            return cut(parts, seams: seams, holes: [window])
        case .rocket:
            var body = Path()
            body.move(to: CGPoint(x: 28, y: 10))
            body.addLine(to: CGPoint(x: 70, y: 10))
            body.addQuadCurve(to: CGPoint(x: 100, y: 20), control: CGPoint(x: 94, y: 10))
            body.addQuadCurve(to: CGPoint(x: 70, y: 30), control: CGPoint(x: 94, y: 30))
            body.addLine(to: CGPoint(x: 28, y: 30))
            body.closeSubpath()
            let parts = [
                body,
                polygon((20, 10), (40, 10), (30, 0), (18, 0)),
                polygon((20, 30), (40, 30), (30, 40), (18, 40)),
                // Two engines, the rope tied on between them.
                polygon((21, 11.5), (28, 11), (28, 17), (21, 16.5)),
                polygon((21, 23.5), (28, 23), (28, 29), (21, 28.5)),
            ]
            var seams = Path(ellipseIn: CGRect(x: 56.5, y: 14.5, width: 11, height: 11))
            seams.move(to: CGPoint(x: 77, y: 6))
            seams.addQuadCurve(to: CGPoint(x: 77, y: 34), control: CGPoint(x: 82, y: 20))
            seams.move(to: CGPoint(x: 44, y: 9))
            seams.addLine(to: CGPoint(x: 44, y: 31))
            seams.move(to: CGPoint(x: 28, y: 11))
            seams.addLine(to: CGPoint(x: 28, y: 29))
            return cut(parts, seams: seams, holes: [])
        case .saucer:
            let rim = Path(ellipseIn: CGRect(x: 2, y: 16, width: 96, height: 16))
            let parts = [
                rim,
                Path(ellipseIn: CGRect(x: 32, y: 2, width: 36, height: 32)).intersection(Path(CGRect(x: 0, y: 0, width: 100, height: 20))),
                Path(ellipseIn: CGRect(x: 34, y: 26, width: 32, height: 14)).intersection(Path(CGRect(x: 0, y: 30, width: 100, height: 16))),
            ]
            let lights = [18.0, 34, 50, 66, 82].map { Path(ellipseIn: CGRect(x: $0 - 2.4, y: 21.6, width: 4.8, height: 4.8)) }
            return cut(parts, seams: rim, holes: lights)
        }
    }

    func polygon(_ points: (CGFloat, CGFloat)...) -> Path {
        var path = Path()
        path.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
        path.closeSubpath()
        return path
    }

    /// The parts as one silhouette, parted along the seams and with the holes taken out.
    func cut(_ parts: [Path], seams: Path, holes: [Path]) -> Path {
        var shape = parts.dropFirst().reduce(parts[0]) { $0.union($1) }
        shape = shape.subtracting(seams.strokedPath(StrokeStyle(lineWidth: Self.gap)))
        for hole in holes { shape = shape.subtracting(hole) }
        return shape
    }
}
