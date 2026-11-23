import Foundation
import Testing

@testable import bondfather

/// Answers each Gemini model from a fixed table and records the requests it received.
private actor StubTransport {
    private(set) var requests: [URLRequest] = []
    private let responses: [String: (status: Int, body: String)]

    init(_ responses: [String: (status: Int, body: String)]) {
        self.responses = responses
    }

    var models: [String] {
        requests.compactMap(Self.model(of:))
    }

    func send(_ request: URLRequest) throws -> (Data, URLResponse) {
        requests.append(request)
        guard let url = request.url, let model = Self.model(of: request), let stub = responses[model],
            let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil, headerFields: nil)
        else { throw URLError(.cannotFindHost) }
        return (Data(stub.body.utf8), response)
    }

    /// `.../models/gemini-4-hydrogen:generateContent` → `gemini-4-hydrogen`
    private static func model(of request: URLRequest) -> String? {
        request.url?.lastPathComponent.split(separator: ":").first.map(String.init)
    }
}

struct GeminiFallbackTests {
    private static let validResponse = #"""
        {"candidates":[{"content":{"parts":[{"text":"{\"sector\":\"Real Estate\",\"businessSummary\":\"Builds homes.\",\"marketFamiliarity\":\"niche\",\"oversubscriptionLikelihood\":\"moderate\"}"}]}}]}
        """#
    private static let errorResponse =
        #"{"error":{"code":503,"message":"The model is overloaded.","status":"UNAVAILABLE"}}"#

    private let primary = GeminiService.primaryModel
    private let fallback = GeminiService.fallbackModel

    private func service(_ stub: StubTransport, apiKey: String = "test-key") -> GeminiService {
        GeminiService(apiKey: apiKey, transport: { try await stub.send($0) })
    }

    @Test func usesPrimaryModelWhenItSucceeds() async throws {
        let stub = StubTransport([primary: (200, Self.validResponse)])
        _ = try await service(stub).enrich(issuerName: "PN Project", ticker: nil)
        #expect(await stub.models == [primary])
    }

    @Test(arguments: [403, 404, 429, 500, 503])
    func fallsBackOnModelSpecificFailures(statusCode: Int) async throws {
        let stub = StubTransport([
            primary: (statusCode, Self.errorResponse),
            fallback: (200, Self.validResponse),
        ])
        let enrichment = try await service(stub).enrich(issuerName: "PN Project", ticker: nil)
        #expect(enrichment.sector == "Real Estate")
        #expect(await stub.models == [primary, fallback])
    }

    @Test func fallsBackOnMalformedAnswer() async throws {
        let stub = StubTransport([
            primary: (200, #"{"candidates":[{"content":{"parts":[{"text":"not json"}]}}]}"#),
            fallback: (200, Self.validResponse),
        ])
        _ = try await service(stub).enrich(issuerName: "PN Project", ticker: nil)
        #expect(await stub.models == [primary, fallback])
    }

    @Test(arguments: [400, 401])
    func doesNotFallBackOnRequestOrKeyErrors(statusCode: Int) async {
        let stub = StubTransport([
            primary: (statusCode, #"{"error":{"message":"API key not valid."}}"#),
            fallback: (200, Self.validResponse),
        ])
        await #expect(throws: GeminiServiceError.self) {
            try await service(stub).enrich(issuerName: "PN Project", ticker: nil)
        }
        #expect(await stub.models == [primary])
    }

    @Test func reportsFallbackErrorWhenBothModelsFail() async {
        let stub = StubTransport([
            primary: (503, Self.errorResponse),
            fallback: (429, #"{"error":{"message":"Resource exhausted."}}"#),
        ])
        let error = await #expect(throws: GeminiServiceError.self) {
            try await service(stub).enrich(issuerName: "PN Project", ticker: nil)
        }
        guard case .requestFailed(let statusCode, _)? = error else {
            Issue.record("Expected requestFailed, got \(String(describing: error))")
            return
        }
        #expect(statusCode == 429)
        #expect(await stub.models == [primary, fallback])
    }

    @Test func doesNotFallBackOnNetworkErrors() {
        #expect(!GeminiService.shouldTryFallback(after: URLError(.notConnectedToInternet)))
        #expect(!GeminiService.shouldTryFallback(after: CancellationError()))
    }

    @Test func sendsKeyInHeaderNotURL() async throws {
        let stub = StubTransport([primary: (200, Self.validResponse)])
        _ = try await service(stub, apiKey: "secret-key").enrich(issuerName: "PN Project", ticker: nil)
        let request = try #require(await stub.requests.first)
        #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "secret-key")
        #expect(request.url?.query == nil)
    }
}
