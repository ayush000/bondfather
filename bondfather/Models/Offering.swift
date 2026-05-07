import Foundation
import CryptoKit

struct Offering: Codable, Identifiable, Hashable {
    let id: String
    let issuerName: String
    let subscriptionStart: Date?
    let subscriptionEnd: Date?
    let markets: [String]

    static func makeId(ticker: String?, issuerName: String) -> String {
        if let ticker, !ticker.isEmpty { return ticker }
        let digest = SHA256.hash(data: Data(issuerName.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
