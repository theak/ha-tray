import Foundation

public enum HAError: Error, Equatable, LocalizedError {
    case unauthorized
    case http(Int)
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized: "Authentication failed — check the token"
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

    /// Fetches all states in a single request and picks out `entityIDs`. Always makes
    /// exactly one request, so it doubles as the auth check before loading the dashboard.
    public func fetchStates(_ entityIDs: [String], timeout: TimeInterval = 1.5) async -> StateFetchResult {
        await withTaskGroup(of: StateFetchResult?.self) { group in
            group.addTask { await fetchAllStates(keeping: Set(entityIDs)) }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? .failed
        }
    }

    private func fetchAllStates(keeping wanted: Set<String>) async -> StateFetchResult {
        guard let (data, status) = try? await get("states") else { return .failed }
        if status == 401 || status == 403 { return .unauthorized }
        guard status == 200, let all = try? JSONDecoder().decode([EntityState].self, from: data) else { return .failed }
        var states: [String: String] = [:]
        for entity in all where wanted.contains(entity.entity_id) {
            states[entity.entity_id] = entity.state
        }
        return .states(states)
    }

    /// `nil` on success.
    public func testConnection() async -> HAError? {
        do {
            let (_, status) = try await get("")
            switch status {
            case 200: return nil
            case 401, 403: return .unauthorized
            default: return .http(status)
            }
        } catch {
            return .network(error.localizedDescription)
        }
    }

    /// Sorted entity IDs whose domain is in `domains`.
    public func allEntities(domains: Set<String>) async throws -> [String] {
        let (data, status) = try await get("states")
        guard status == 200 else { throw status == 401 || status == 403 ? HAError.unauthorized : HAError.http(status) }
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
