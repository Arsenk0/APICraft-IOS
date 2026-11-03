import Foundation
import SwiftData

@Model
final class SDTestAssertion {
    @Attribute(.unique) var id: UUID
    var target: AssertionTarget
    var keyPath: String?
    var comparison: AssertionComparison
    var expectedValue: String
    var isEnabled: Bool
    
    init(
        target: AssertionTarget,
        keyPath: String? = nil,
        comparison: AssertionComparison,
        expectedValue: String,
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.target = target
        self.keyPath = keyPath
        self.comparison = comparison
        self.expectedValue = expectedValue
        self.isEnabled = isEnabled
    }
}
