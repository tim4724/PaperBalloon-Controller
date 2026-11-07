import XCTest
@testable import PaperBalloon

/// Runs the shared cases in tests/haptic-composition.json (bundled as a resource by
/// project.yml) — the Android port runs the same file (HapticCompositionTest.kt).
final class HapticCompositionTests: XCTestCase {

    private struct Cases: Decodable {
        struct Case: Decodable { let input: String?; let steps: [Step] }
        /// `[primitive, scale, rest in ms]`.
        struct Step: Decodable {
            let primitive: String
            let scale: Double
            let delay: Int

            init(from decoder: Decoder) throws {
                var fields = try decoder.unkeyedContainer()
                primitive = try fields.decode(String.self)
                scale = try fields.decode(Double.self)
                delay = try fields.decode(Int.self)
            }
        }
        let cases: [Case]
    }

    func testParseHapticComposition() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "haptic-composition", withExtension: "json"))
        for c in try JSONDecoder().decode(Cases.self, from: Data(contentsOf: url)).cases {
            let input = c.input ?? "nil"
            let actual = parseHapticComposition(c.input)
            XCTAssertEqual(actual.count, c.steps.count, "\(input): step count")
            for (i, (want, got)) in zip(c.steps, actual).enumerated() {
                let at = "\(input), step \(i)"
                XCTAssertEqual(got.primitive.rawValue, want.primitive, at)
                XCTAssertEqual(got.scale, want.scale, accuracy: 1e-6, at)
                XCTAssertEqual(Int((got.delay * 1000).rounded()), want.delay, at)
            }
        }
    }
}
