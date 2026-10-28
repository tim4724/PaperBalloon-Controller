import XCTest
@testable import PaperBalloon

/// §8 instance name → card label. Mirrors NearbyLabelTest.kt.
final class NearbyLabelTests: XCTestCase {

    func testDropsDisplaySuffix() {
        XCTAssertEqual(sanitizeAdvertLabel("Living Room · Paper Balloon"), "Living Room")
        // Longer than the cap on the wire, so this also pins stripping before capping.
        XCTAssertEqual(sanitizeAdvertLabel("Living Room · Paper Balloon (2)"), "Living Room (2)")
        // A name without the suffix (tvOS, older displays) only gets its whitespace normalised.
        XCTAssertEqual(sanitizeAdvertLabel("  Living   Room "), "Living Room")
        // Only a trailing suffix is the marker.
        XCTAssertEqual(sanitizeAdvertLabel("Paper Balloon · Paper Balloon Club"), "Paper Balloon · Paper Ba")
    }
}
