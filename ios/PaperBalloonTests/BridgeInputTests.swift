import XCTest
@testable import PaperBalloon

/// What a page posts to the bridge is untrusted (CONTRACT.md §11, §12). iOS only: on
/// Android the WebView's own `navigator.vibrate` and the typed Java bridge do this work.
final class BridgeInputTests: XCTestCase {

    func testVibrationPattern() {
        XCTAssertEqual(parseVibrationPattern("200"), [200])
        XCTAssertEqual(parseVibrationPattern("10,50,10"), [10, 50, 10])
        XCTAssertEqual(parseVibrationPattern("0"), [0])
        // Nothing to play.
        XCTAssertEqual(parseVibrationPattern(nil), [])
        XCTAssertEqual(parseVibrationPattern(""), [])
        // A malformed entry keeps the valid prefix.
        XCTAssertEqual(parseVibrationPattern("10,x,10"), [10])
        XCTAssertEqual(parseVibrationPattern("10,-5,10"), [10])
        XCTAssertEqual(parseVibrationPattern("10, 20"), [10])
        XCTAssertEqual(parseVibrationPattern("1.5"), [])
        XCTAssertEqual(parseVibrationPattern("99999999999999999999"), [])
        // 5 s in all: the entry that crosses it is shortened, the rest dropped.
        XCTAssertEqual(parseVibrationPattern("6000"), [5000])
        XCTAssertEqual(parseVibrationPattern("3000,1000,3000,10"), [3000, 1000, 1000])
        // 128 entries, and 1024 units of input.
        XCTAssertEqual(parseVibrationPattern(Array(repeating: "1", count: 200).joined(separator: ",")).count, 128)
        XCTAssertEqual(parseVibrationPattern(String(repeating: "1,", count: 600)), [])
    }

    func testHaptic() {
        XCTAssertEqual(parseHaptic("click,0.7")?.primitive, .click)
        XCTAssertEqual(parseHaptic("click,0.7")?.scale, 0.7)
        XCTAssertEqual(parseHaptic("slow_rise,1")?.primitive, .slowRise)
        // The scale is clamped to 0–1.
        XCTAssertEqual(parseHaptic("click,2")?.scale, 1)
        XCTAssertEqual(parseHaptic("click,-1")?.scale, 0)
        // Anything else plays nothing.
        for input in [nil, "", "click", "click,0.5,3", "nope,0.5", "Click,0.5", "click,abc", "click,nan", "click,inf",
                      "click," + String(repeating: "1", count: 64)] {
            XCTAssertNil(parseHaptic(input), input ?? "nil")
        }
    }
}
