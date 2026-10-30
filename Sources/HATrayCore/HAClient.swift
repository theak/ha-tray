import Foundation

public enum HAError: Error, Equatable, LocalizedError {
    case unauthorized
    case http(Int)
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized: "Unauthorized (401)"
        case .http(let code): "HTTP \(code)"
        case .network(let message): message
        }
    }
}

/// Minimal read-only Home Assistant REST client.
public struct HAClient: Sendable {
    public let baseURL: URL
    let token: String
    let session: URLSession

    public init(baseURL: URL, token: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    private struct EntityState: Decodable {
        let entity_id: String
        let state: String
    }

    private enum Outcome {
        case state(String, String)
        case notFound
        case error
    }

    /// Fetches the given entities concurrently. Missing entities are omitted; the
    /// result is `.failed` on timeout or when every request fails for another reason.
    public func fetchStates(_ entityIDs: [String], timeout: TimeInterval = 1.5) async -> StateFetchResult {
        guard !entityIDs.isEmpty else { return .states([:]) }
        return await withTaskGroup(of: [Outcome]?.self) { group in
            group.addTask {
                await withTaskGroup(of: Outcome.self) { inner in
                    for id in Set(entityIDs) { inner.addTask { await fetchState(id) } }
                    return await inner.reduce(into: []) { $0.append($1) }
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            guard let outcomes = first else { return .failed }
            var states: [String: String] = [:]
            var anySucceeded = false
            for outcome in outcomes {
                switch outcome {
                case .state(let id, let state): states[id] = state; anySucceeded = true
                case .notFound: anySucceeded = true
                case .error: break
                }
            }
            return anySucceeded ? .states(states) : .failed
        }
    }

    private func fetchState(_ entityID: String) async -> Outcome {
        guard let (data, status) = try? await get("states/\(entityID)") else { return .error }
        if status == 404 { return .notFound }
        guard status == 200, let s = try? JSONDecoder().decode(EntityState.self, from: data) else { return .error }
        return .state(s.entity_id, s.state)
    }

    /// `nil` on success.
    public func testConnection() async -> HAError? {
        do {
            let (_, status) = try await get("")
            switch status {
            case 200: return nil
            case 401: return .unauthorized
            default: return .http(status)
            }
        } catch {
            return .network(error.localizedDescription)
        }
    }

    /// Sorted entity IDs whose domain is in `domains`.
    public func allEntities(domains: Set<String>) async throws -> [String] {
        let (data, status) = try await get("states")
        guard status == 200 else { throw status == 401 ? HAError.unauthorized : HAError.http(status) }
        return try JSONDecoder().decode([EntityState].self, from: data)
            .map(\.entity_id)
            .filter { domains.contains(String($0.prefix { $0 != "." })) }
            .sorted()
    }

    private func get(_ path: String) async throws -> (Data, Int) {
        var request = URLRequest(url: HAURLs.api(base: baseURL, path))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}
