import XCTest
@testable import PaperBalloon

/// CONTRACT.md §13: the default App Clip link a game page opens carries its join URL in
/// `url`. iOS only: Android carries the room through the Play referrer instead.
final class IncomingJoinLinkTests: XCTestCase {

    private let join = "https://hexstacker.com/A3KX9p#fra-1"

    func testUnwrapsTheDefaultAppClipLink() throws {
        // As a page builds it: encodeURIComponent(joinUrl).
        let link = try XCTUnwrap(URL(string: "https://appclip.apple.com/id?p=games.paperballoon.controller.Clip"
            + "&url=https%3A%2F%2Fhexstacker.com%2FA3KX9p%23fra-1"))
        XCTAssertEqual(incomingJoinLink(link), join)
    }

    func testADefaultLinkWithoutARoomJoinsNothing() throws {
        let link = try XCTUnwrap(URL(string: "https://appclip.apple.com/id?p=games.paperballoon.controller.Clip"))
        XCTAssertNil(incomingJoinLink(link))
    }

    func testAnyOtherLinkIsItsOwnJoinLink() throws {
        XCTAssertEqual(incomingJoinLink(try XCTUnwrap(URL(string: join))), join)
    }
}
