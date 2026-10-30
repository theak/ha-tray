import XCTest
@testable import HATrayCore

/// Serves canned responses keyed by URL path.
final class StubProtocol: URLProtocol {
    struct Response { var status: Int = 200; var body: String = ""; var delay: TimeInterval = 0; var fail = false }
    nonisolated(unsafe) static var responses: [String: Response] = [:]
    nonisolated(unsafe) static var lastAuthorization: String?
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.lastAuthorization = request.value(forHTTPHeaderField: "Authorization")
        Self.requestCount += 1
        let r = Self.responses[request.url!.path] ?? Response(status: 404)
        DispatchQueue.global().asyncAfter(deadline: .now() + r.delay) { [self] in
            if r.fail {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
                return
            }
            let resp = HTTPURLResponse(url: request.url!, statusCode: r.status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(r.body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}

final class HAClientTests: XCTestCase {
    var client: HAClient!

    override func setUp() {
        StubProtocol.responses = [:]
        StubProtocol.lastAuthorization = nil
        StubProtocol.requestCount = 0
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        client = HAClient(baseURL: URL(string: "http://ha:8123")!, token: "tok", session: URLSession(configuration: config))
    }

    let allStates = StubProtocol.Response(body: #"[{"entity_id":"a","state":"on"},{"entity_id":"b","state":"off"},{"entity_id":"c","state":"on"}]"#)

    func testFetchStatesUsesOneRequestAndSendsBearer() async {
        StubProtocol.responses["/api/states"] = allStates
        let result = await client.fetchStates(["a", "b", "missing"])
        XCTAssertEqual(result, .states(["a": "on", "b": "off"]))
        XCTAssertEqual(StubProtocol.requestCount, 1)
        XCTAssertEqual(StubProtocol.lastAuthorization, "Bearer tok")
    }

    func testFetchStatesWithNoEntitiesStillChecksAuth() async {
        StubProtocol.responses["/api/states"] = .init(status: 401)
        let result = await client.fetchStates([])
        XCTAssertEqual(result, .unauthorized)
        XCTAssertEqual(StubProtocol.requestCount, 1)
    }

    func test401And403AreUnauthorized() async {
        for status in [401, 403] {
            StubProtocol.responses["/api/states"] = .init(status: status)
            let result = await client.fetchStates(["a"])
            XCTAssertEqual(result, .unauthorized, "\(status)")
        }
    }

    func testServerErrorIsFailed() async {
        StubProtocol.responses["/api/states"] = .init(status: 500)
        let result = await client.fetchStates(["a"])
        XCTAssertEqual(result, .failed)
    }

    func testNetworkErrorIsFailed() async {
        StubProtocol.responses["/api/states"] = .init(fail: true)
        let result = await client.fetchStates(["a"])
        XCTAssertEqual(result, .failed)
    }

    func testTimeoutIsFailed() async {
        StubProtocol.responses["/api/states"] = .init(body: "[]", delay: 3)
        let start = Date()
        let result = await client.fetchStates(["a"], timeout: 0.2)
        XCTAssertEqual(result, .failed)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
    }

    func testConnection403IsUnauthorized() async {
        StubProtocol.responses["/api"] = .init(status: 403)
        let result = await client.testConnection()
        XCTAssertEqual(result, .unauthorized)
    }

    func testConnection401() async {
        StubProtocol.responses["/api"] = .init(status: 401)
        let result = await client.testConnection()
        XCTAssertEqual(result, .unauthorized)
        XCTAssertEqual(HAError.unauthorized.errorDescription, "Authentication failed — check the token")
    }

    func testAllEntitiesFiltersByDomain() async throws {
        StubProtocol.responses["/api/states"] = .init(body: #"[{"entity_id":"switch.x","state":"on"},{"entity_id":"sensor.y","state":"1"},{"entity_id":"input_boolean.a","state":"off"}]"#)
        let ids = try await client.allEntities(domains: ["switch", "input_boolean"])
        XCTAssertEqual(ids, ["input_boolean.a", "switch.x"])
    }

    func testLiveConnection() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let base = env["HA_URL"].flatMap(URL.init(string:)), let token = env["HA_TOKEN"] else {
            throw XCTSkip("HA_URL / HA_TOKEN not set")
        }
        let live = HAClient(baseURL: base, token: token)
        let conn = await live.testConnection()
        XCTAssertNil(conn)
        let result = await live.fetchStates(["sun.sun"], timeout: 5)
        guard case .states(let states) = result else { return XCTFail("fetch failed") }
        XCTAssertNotNil(states["sun.sun"])
    }
}
