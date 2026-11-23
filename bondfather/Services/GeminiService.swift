import Foundation

nonisolated enum GeminiServiceError: LocalizedError {
    case missingAPIKey
    case requestFailed(statusCode: Int, message: String?)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add a Gemini API key in Settings to see issuer insights."
        case .requestFailed(429, _):
            "Gemini rate limit reached. Try again in a minute."
        case .requestFailed(let statusCode, let message):
            "Gemini request failed (\(statusCode))" + (message.map { ": \($0)" } ?? ".")
        case .emptyResponse:
            "Gemini returned an empty response."
        }
    }
}

/// Generates issuer insights with Gemini structured JSON output.
nonisolated struct GeminiService: Sendable {
    static let model = "gemini-4-hydrogen"
    private static let endpoint = URL(
        string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
    )!

    let apiKey: String
    var session: URLSession = .shared

    func enrich(issuerName: String, ticker: String?) async throws -> OfferingEnrichment {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // A header keeps the key out of URLs, which can end up in logs and crash reports.
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(Self.makeRequest(issuerName: issuerName, ticker: ticker))

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = try? JSONDecoder().decode(ErrorResponse.self, from: data).error.message
            throw GeminiServiceError.requestFailed(statusCode: http.statusCode, message: message)
        }
        return try Self.parseEnrichment(from: data)
    }

    static func makeRequest(issuerName: String, ticker: String?) -> GenerateContentRequest {
        let tickerLine = ticker.map { "Bond ticker: \($0)\n" } ?? ""
        let prompt = """
            You are a financial research assistant. The user is evaluating a bond offering on the Nasdaq Baltic Tallinn exchange. Provide a concise qualitative assessment of the issuer.

            \(tickerLine)Issuer: \(issuerName)

            Fields:
            - sector: Short industry label (e.g., "Real Estate", "Banking/Fintech", "Energy").
            - businessSummary: 1–2 sentence description of what the company does.
            - companyAgeYears: Approximate years since founding. Omit if unknown.
            - marketFamiliarity: "household" if widely known to retail investors, "established" if known in its sector, "niche" if obscure.
            - relativeRiskScore: 1 (sovereign / risk-free) to 5 (high-yield / unsecured). Reflect the bond's credit risk relative to government bonds. Omit if you cannot reasonably judge.
            - oversubscriptionLikelihood: "critical" if highly likely to be oversubscribed, "moderate" if it may be, "unlikely" otherwise.

            Base your assessment on public knowledge of the issuer. If the issuer is unknown to you, infer cautiously from the name and label marketFamiliarity as "niche".
            """

        let schema = JSONSchema(
            type: "object",
            properties: [
                "sector": JSONSchema(type: "string"),
                "businessSummary": JSONSchema(type: "string"),
                "companyAgeYears": JSONSchema(type: "integer", minimum: 0),
                "marketFamiliarity": JSONSchema(type: "string", enum: MarketFamiliarity.allCases.map(\.rawValue)),
                "relativeRiskScore": JSONSchema(type: "integer", minimum: 1, maximum: 5),
                "oversubscriptionLikelihood": JSONSchema(
                    type: "string",
                    enum: OversubscriptionLikelihood.allCases.map(\.rawValue)
                ),
            ],
            required: ["sector", "businessSummary", "marketFamiliarity", "oversubscriptionLikelihood"]
        )

        return GenerateContentRequest(
            contents: [.init(parts: [.init(text: prompt)])],
            generationConfig: .init(
                responseJsonSchema: schema,
                // The model defaults to high. A short classification doesn't need that; low keeps it fast and cheap.
                thinkingConfig: .init(thinkingLevel: "low")
            )
        )
    }

    static func parseEnrichment(from data: Data) throws -> OfferingEnrichment {
        let response = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        let text =
            response.candidates?.first?.content?.parts?
            .filter { $0.thought != true }
            .compactMap(\.text)
            .joined() ?? ""
        guard !text.isEmpty else { throw GeminiServiceError.emptyResponse }
        return try JSONDecoder().decode(OfferingEnrichment.self, from: Data(text.utf8))
    }
}

// MARK: - Wire types

nonisolated struct GenerateContentRequest: Encodable, Sendable {
    struct Content: Encodable, Sendable {
        let parts: [Part]
    }

    struct Part: Encodable, Sendable {
        let text: String
    }

    struct GenerationConfig: Encodable, Sendable {
        var responseMimeType = "application/json"
        let responseJsonSchema: JSONSchema
        let thinkingConfig: ThinkingConfig
    }

    struct ThinkingConfig: Encodable, Sendable {
        let thinkingLevel: String
    }

    let contents: [Content]
    let generationConfig: GenerationConfig
}

/// The subset of JSON Schema that the app's response schema uses.
nonisolated struct JSONSchema: Encodable, Sendable {
    var type: String
    var properties: [String: JSONSchema]?
    var required: [String]?
    var `enum`: [String]?
    var minimum: Int?
    var maximum: Int?

    init(
        type: String,
        properties: [String: JSONSchema]? = nil,
        required: [String]? = nil,
        enum: [String]? = nil,
        minimum: Int? = nil,
        maximum: Int? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.enum = `enum`
        self.minimum = minimum
        self.maximum = maximum
    }
}

private nonisolated struct GenerateContentResponse: Decodable {
    struct Candidate: Decodable {
        let content: Content?
    }

    struct Content: Decodable {
        let parts: [Part]?
    }

    struct Part: Decodable {
        let text: String?
        let thought: Bool?
    }

    let candidates: [Candidate]?
}

private nonisolated struct ErrorResponse: Decodable {
    struct Body: Decodable {
        let message: String
    }

    let error: Body
}
