import XCTest
@testable import PaperBalloon

/// Runs the shared cases in tests/join-resolver.json (bundled as a resource by
/// project.yml) — the Android port runs the same file (JoinResolverTest.kt).
final class JoinResolverTests: XCTestCase {

    private struct Cases: Decodable {
        struct GameCase: Decodable { let id: String; let hosts: [String] }
        struct Resolve: Decodable { let input: String; let reject: Bool?; let game: String?; let room: String? }
        struct Originless: Decodable { let input: String; let code: String? }
        let games: [GameCase]
        let resolve: [Resolve]
        let originlessCode: [Originless]
    }

    private func loadCases() throws -> Cases {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "join-resolver", withExtension: "json"))
        return try JSONDecoder().decode(Cases.self, from: Data(contentsOf: url))
    }

    func testResolve() throws {
        let cases = try loadCases()
        let games = cases.games.map { Game(id: $0.id, name: $0.id, status: "live", hosts: $0.hosts) }
        for c in cases.resolve {
            let outcome = JoinResolver.resolve(c.input, games: games)
            if c.reject == true {
                guard case .failure = outcome else {
                    XCTFail("\(c.input): expected a rejection, got \(outcome)")
                    continue
                }
            } else {
                guard case let .success(game, roomCode, joinUrl) = outcome else {
                    XCTFail("\(c.input): expected a join, got \(outcome)")
                    continue
                }
                XCTAssertEqual(game.id, c.game, c.input)
                XCTAssertEqual(roomCode, c.room, c.input)
                XCTAssertEqual(joinUrl, c.input.trimmingCharacters(in: .whitespacesAndNewlines), c.input)
            }
        }
    }

    func testOriginlessCode() throws {
        for c in try loadCases().originlessCode {
            XCTAssertEqual(originlessCode(c.input), c.code, c.input)
        }
    }
}
