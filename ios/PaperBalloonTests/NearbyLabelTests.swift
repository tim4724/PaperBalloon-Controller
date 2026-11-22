import XCTest
@testable import PaperBalloon

/// Runs the shared cases in tests/nearby-label.json (bundled as a resource by
/// project.yml) — the Android port runs the same file (NearbyLabelTest.kt).
final class NearbyLabelTests: XCTestCase {

    private struct Cases: Decodable {
        struct Case: Decodable { let input: String; let label: String }
        let cases: [Case]
    }

    func testSanitizeAdvertLabel() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "nearby-label", withExtension: "json"))
        for c in try JSONDecoder().decode(Cases.self, from: Data(contentsOf: url)).cases {
            XCTAssertEqual(sanitizeAdvertLabel(c.input), c.label, c.input)
        }
    }
}
