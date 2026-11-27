import Foundation

// MARK: - Lookup result

/// How often the rooms on screen are re-checked against the relay. One cadence for both
/// card kinds — a rejoin card and a nearby card make the same promise ("you can enter
/// this"), so they go stale the same way and are refreshed by the same probe.
let roomPollInterval: Duration = .seconds(10)

enum RoomLookup: Equatable {
    /// Room exists. url = the host-declared §6 controller-URL template (nil if none/blank)
    /// and the only thing that says where the room lives — UNTRUSTED, so resolve it
    /// through the allow-list. Nil leaves nothing to resolve the code with.
    ///
    /// clients/maxClients are the room's live occupancy. Both 0 when the relay omitted
    /// them, and `isFull` is false in that case rather than guessing, so a relay that
    /// doesn't report occupancy never hides a joinable room.
    case found(url: String?, clients: Int, maxClients: Int)
    case notFound
    case error
}

// MARK: - Directory probe

enum RoomDirectory {

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }()

    /// GET {PB.relayBase}/room/{androidUriEncode(code)}. Never throws.
    /// 200 + JSON object → .found; 404 → .notFound; anything else → .error.
    /// Empty trimmed code → .notFound (no network).
    static func lookup(code: String) async -> RoomLookup {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .notFound
        }
        guard let url = URL(string: PB.relayBase + "/room/" + androidUriEncode(trimmed)) else {
            return .error
        }
        do {
            let (data, response) = try await session.data(for: URLRequest(url: url))
            guard let http = response as? HTTPURLResponse else { return .error }
            switch http.statusCode {
            case 200:
                guard let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return .error
                }
                let template = (body["url"] as? String)
                    .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                return .found(url: template,
                              clients: body["clients"] as? Int ?? 0,
                              maxClients: body["maxClients"] as? Int ?? 0)
            case 404:
                return .notFound
            default:
                return .error
            }
        } catch {
            return .error
        }
    }
}

// MARK: - Join resolution

/// The one entry point for every join input: typed code, scanned QR, Universal Link,
/// rejoin and nearby URLs. An input that carries its own origin IS the controller and
/// resolves offline; an origin-less one (`originlessCode`) names a room but not a game,
/// and only the relay directory knows which game owns that code — there is nothing to
/// guess with, so a code the directory can't place does not join.
///
/// The relay names the owner through the §6 controller-URL template the display
/// registered at room create; that template is host-declared and UNTRUSTED, so it is
/// re-validated against the manifest allow-list before it loads.
func resolveJoin(_ raw: String, games: [Game]) async -> JoinOutcome {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return .failure(message: String(localized: "Enter a room code."))
    }
    // Has an origin of its own (or is a launcher link with no code at all): nothing to
    // look up — the offline resolver already knows what to load, or why it can't.
    guard let code = originlessCode(trimmed), !code.isEmpty else {
        return JoinResolver.resolve(trimmed, games: games)
    }
    return resolveLookup(await RoomDirectory.lookup(code: code), games: games)
}

/// The decision on the relay's answer — separate from `resolveJoin` so the home poll,
/// which probes for its own reasons, makes a nearby card (`nearbyRoom`) from the same
/// answer instead of probing a second time.
func resolveLookup(_ lookup: RoomLookup, games: [Game]) -> JoinOutcome {
    // Deliberately NOT refused when full, though the lookup reports it: a full room still
    // takes its own players back (the relay swaps a stored clientId into the slot it is
    // holding for them), and from a code alone we cannot tell that player from a stranger.
    // Refusing here locks someone out of the room they are already in. Let the load happen
    // and let the relay decide — a stranger bounces back on `game_full`, which the shell
    // already turns into a banner. Only the home cards act on `isFull`: a card is an
    // offer, and a full room has no seat to offer one tap into.

    switch lookup {
    case .found(let url, _, _):
        // The relay knows the room and handed back the controller URL → load exactly
        // that (untrusted; re-validated). A url that is itself origin-less (a
        // paperballoon.games/<code> template) declares nothing the directory hadn't
        // already told us, so it doesn't count as one; nor does none at all. §6:
        // registering a usable template is what makes a code joinable, so either is a
        // display bug, and the honest answer is to say the code can't be placed rather
        // than guess a game for it.
        if let url, originlessCode(url) == nil {
            return JoinResolver.resolve(url, games: games)
        }
        return .failure(message: String(localized: "This code can’t be matched to a game right now."))
    case .notFound:
        return .failure(message: String(localized: "Room not found."))
    case .error:
        return .failure(message: String(localized: "Couldn’t reach the server. Try again."))
    }
}

extension RoomLookup {
    /// The display occupies a slot too, so this is exact, not off by one.
    var isFull: Bool {
        guard case .found(_, let clients, let maxClients) = self else { return false }
        return maxClients > 0 && clients >= maxClients
    }
}
