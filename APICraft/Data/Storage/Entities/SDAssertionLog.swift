import Foundation
import SwiftData

@Model
final class SDAssertionLog {
    @Attribute(.unique) var id: UUID
    var assertionDescription: String
    var isPassed: Bool
    var failureReason: String?
    
    init(assertionDescription: String, isPassed: Bool, failureReason: String? = nil) {
        self.id = UUID()
        self.assertionDescription = assertionDescription
        self.isPassed = isPassed
        self.failureReason = failureReason
    }
}
