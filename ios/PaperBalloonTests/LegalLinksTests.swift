import XCTest
@testable import PaperBalloon

/// Runs the shared cases in tests/legal-links.json (bundled as a resource by
/// project.yml) — the Android port runs the same file (LegalLinksTest.kt).
final class LegalLinksTests: XCTestCase {

    private struct Cases: Decodable {
        struct Case: Decodable { let input: String; let legal: Bool }
        let cases: [Case]
    }

    func testScannedLegalUrl() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "legal-links", withExtension: "json"))
        for c in try JSONDecoder().decode(Cases.self, from: Data(contentsOf: url)).cases {
            XCTAssertEqual(PB.legalDocUrl(c.input), c.legal ? c.input : nil, c.input)
        }
    }
}
