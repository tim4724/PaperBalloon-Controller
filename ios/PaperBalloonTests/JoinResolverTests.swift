import XCTest
@testable import PaperBalloon

/// Runs the shared cases in tests/join-resolver.json (bundled as a resource by
/// project.yml) — the Android port runs the same file (JoinResolverTest.kt).
final class JoinResolverTests: XCTestCase {

    private struct Cases: Decodable {
        struct GameCase: Decodable { let id: String; let hosts: [String] }
        struct Resolve: Decodable { let input: String; let reject: Bool?; let game: String?; let room: String? }
        struct Originless: Decodable { let input: String; let code: String? }
        struct Lookups: Decodable {
            struct Lookup: Decodable { let kind: String; let url: String?; let clients: Int?; let maxClients: Int? }
            let lookups: [Lookup]
            let game: String?
            let url: String?
            let fail: String?
        }
        let games: [GameCase]
        let resolve: [Resolve]
        let resolveLookups: [Lookups]
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

    func testResolveLookups() throws {
        let cases = try loadCases()
        let games = cases.games.map { Game(id: $0.id, name: $0.id, status: "live", hosts: $0.hosts) }
        let failures = [
            "notARoom": String(localized: "That code isn’t a Paper Balloon room."),
            "unmatched": String(localized: "This code can’t be matched to a game right now."),
            "notFound": String(localized: "Room not found."),
            "unreachable": String(localized: "Couldn’t reach the server. Try again."),
        ]
        for (i, c) in cases.resolveLookups.enumerated() {
            let lookups: [RoomLookup] = try c.lookups.map {
                switch $0.kind {
                case "found": .found(url: $0.url, clients: $0.clients ?? 0, maxClients: $0.maxClients ?? 0)
                case "notFound": .notFound
                case "error": .error
                default: throw NSError(domain: "unknown lookup kind \($0.kind)", code: 0)
                }
            }
            let outcome = resolveLookups(lookups, games: games)
            if let fail = c.fail {
                XCTAssertEqual(outcome, .failure(message: try XCTUnwrap(failures[fail], "unknown failure \(fail)")), "case \(i)")
            } else {
                guard case let .success(game, _, joinUrl) = outcome else {
                    XCTFail("case \(i): expected a join, got \(outcome)")
                    continue
                }
                XCTAssertEqual(game.id, c.game, "case \(i)")
                XCTAssertEqual(joinUrl, c.url, "case \(i)")
            }
        }
    }

    func testOriginlessCode() throws {
        for c in try loadCases().originlessCode {
            XCTAssertEqual(originlessCode(c.input), c.code, c.input)
        }
    }
}
