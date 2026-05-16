import Foundation

enum GeminiServiceError: Error {
    case missingAPIKey
    case invalidResponse
}

struct GeminiService {
    private static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    func enrich(issuerName: String, ticker: String?) async throws -> OfferingEnrichment {
        guard let apiKey = Secrets.geminiAPIKey else { throw GeminiServiceError.missingAPIKey }
        guard var components = URLComponents(string: Self.endpoint) else { throw GeminiServiceError.invalidResponse }
        components.queryItems = [.init(name: "key", value: apiKey)]
        guard let url = components.url else { throw GeminiServiceError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: makeBody(issuerName: issuerName, ticker: ticker))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GeminiServiceError.invalidResponse
        }
        return try parseEnrichment(from: data)
    }

    private func makeBody(issuerName: String, ticker: String?) -> [String: Any] {
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

        return [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "OBJECT",
                    "properties": [
                        "sector": ["type": "STRING"],
                        "businessSummary": ["type": "STRING"],
                        "companyAgeYears": ["type": "INTEGER", "nullable": true],
                        "marketFamiliarity": ["type": "STRING", "enum": ["household", "established", "niche"]],
                        "relativeRiskScore": ["type": "INTEGER", "nullable": true, "minimum": 1, "maximum": 5],
                        "oversubscriptionLikelihood": ["type": "STRING", "enum": ["critical", "moderate", "unlikely"]],
                    ],
                    "required": ["sector", "businessSummary", "marketFamiliarity", "oversubscriptionLikelihood"],
                    "propertyOrdering": [
                        "sector", "businessSummary", "companyAgeYears",
                        "marketFamiliarity", "relativeRiskScore", "oversubscriptionLikelihood"
                    ],
                ],
            ],
        ]
    }

    private func parseEnrichment(from data: Data) throws -> OfferingEnrichment {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String,
              let jsonData = text.data(using: .utf8)
        else { throw GeminiServiceError.invalidResponse }
        return try JSONDecoder().decode(OfferingEnrichment.self, from: jsonData)
    }
}
