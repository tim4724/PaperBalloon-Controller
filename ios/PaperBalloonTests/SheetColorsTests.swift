import SwiftUI
import XCTest
@testable import PaperBalloon

/// Runs the shared cases in tests/sheet-colors.json (bundled as a resource by
/// project.yml) — the Android port runs the same file (SheetColorsTest.kt).
final class SheetColorsTests: XCTestCase {

    private struct Cases: Decodable {
        struct Case: Decodable { let input: String; let rgb: [Int]? }
        let cases: [Case]
    }

    func testParseCssRgb() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "sheet-colors", withExtension: "json"))
        for c in try JSONDecoder().decode(Cases.self, from: Data(contentsOf: url)).cases {
            XCTAssertEqual(parseCssRgb(c.input).map(Self.components), c.rgb, c.input)
        }
    }

    private static func components(_ color: Color) -> [Int] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b].map { Int(($0 * 255).rounded()) }
    }
}
