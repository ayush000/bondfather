import Foundation
import Testing

@testable import bondfather

struct GeminiServiceTests {
    @Test func parsesStructuredResponse() throws {
        let response = #"""
            {
              "candidates": [{
                "content": {
                  "role": "model",
                  "parts": [{
                    "text": "{\"sector\":\"Real Estate\",\"businessSummary\":\"Builds homes.\",\"companyAgeYears\":12,\"marketFamiliarity\":\"niche\",\"relativeRiskScore\":4,\"oversubscriptionLikelihood\":\"moderate\"}"
                  }]
                },
                "finishReason": "STOP"
              }]
            }
            """#
        let enrichment = try GeminiService.parseEnrichment(from: Data(response.utf8))
        #expect(
            enrichment
                == OfferingEnrichment(
                    sector: "Real Estate",
                    businessSummary: "Builds homes.",
                    companyAgeYears: 12,
                    marketFamiliarity: .niche,
                    relativeRiskScore: 4,
                    oversubscriptionLikelihood: .moderate
                ))
    }

    @Test func toleratesOmittedOptionalFields() throws {
        let response = #"""
            {"candidates":[{"content":{"parts":[{"text":"{\"sector\":\"Energy\",\"businessSummary\":\"\",\"marketFamiliarity\":\"household\",\"oversubscriptionLikelihood\":\"critical\"}"}]}}]}
            """#
        let enrichment = try GeminiService.parseEnrichment(from: Data(response.utf8))
        #expect(enrichment.companyAgeYears == nil)
        #expect(enrichment.relativeRiskScore == nil)
    }

    @Test func rejectsEmptyResponse() {
        #expect(throws: GeminiServiceError.self) {
            try GeminiService.parseEnrichment(from: Data(#"{"candidates":[]}"#.utf8))
        }
    }

    @Test func requestUsesJSONSchemaAndLowThinking() throws {
        let request = GeminiService.makeRequest(issuerName: "PN Project", ticker: "PNPBOND_13")
        let json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )
        let config = try #require(json["generationConfig"] as? [String: Any])
        #expect(config["responseMimeType"] as? String == "application/json")
        #expect((config["thinkingConfig"] as? [String: Any])?["thinkingLevel"] as? String == "low")

        let schema = try #require(config["responseJsonSchema"] as? [String: Any])
        let properties = try #require(schema["properties"] as? [String: Any])
        #expect(
            Set(properties.keys) == [
                "sector", "businessSummary", "companyAgeYears",
                "marketFamiliarity", "relativeRiskScore", "oversubscriptionLikelihood",
            ])
        let familiarity = try #require(properties["marketFamiliarity"] as? [String: Any])
        #expect(familiarity["enum"] as? [String] == ["household", "established", "niche"])
    }

    @Test func promptIncludesTickerOnlyWhenKnown() {
        let withTicker = GeminiService.makeRequest(issuerName: "PN Project", ticker: "PNPBOND_13")
        let withoutTicker = GeminiService.makeRequest(issuerName: "PN Project", ticker: nil)
        #expect(withTicker.contents[0].parts[0].text.contains("Bond ticker: PNPBOND_13"))
        #expect(!withoutTicker.contents[0].parts[0].text.contains("Bond ticker"))
    }

    @Test func describesRateLimitErrors() {
        let error = GeminiServiceError.requestFailed(statusCode: 429, message: "Resource exhausted")
        #expect(error.localizedDescription.contains("rate limit"))
    }
}
