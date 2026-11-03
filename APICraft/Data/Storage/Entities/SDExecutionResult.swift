import Foundation
import SwiftData

@Model
final class SDExecutionResult {
    @Attribute(.unique) var id: UUID
    var statusCode: Int
    var responseDurationMs: Double
    var responseBodySize: Int
    var responseBody: String?
    var responseHeadersData: Data?
    var executedAt: Date
    var isAllAssertionsPassed: Bool
    
    var request: SDRequest?
    
    @Relationship(deleteRule: .cascade)
    var assertionLogs: [SDAssertionLog] = []
    
    init(
        statusCode: Int,
        responseDurationMs: Double,
        responseBodySize: Int,
        responseBody: String? = nil,
        responseHeadersData: Data? = nil,
        isAllAssertionsPassed: Bool
    ) {
        self.id = UUID()
        self.statusCode = statusCode
        self.responseDurationMs = responseDurationMs
        self.responseBodySize = responseBodySize
        self.responseBody = responseBody
        self.responseHeadersData = responseHeadersData
        self.executedAt = Date()
        self.isAllAssertionsPassed = isAllAssertionsPassed
    }
}
