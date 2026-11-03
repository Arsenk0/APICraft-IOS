import Foundation
import SwiftData

@Model
final class SDEnvironment {
    @Attribute(.unique) var id: UUID
    var name: String
    var isSelected: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \SDEnvironmentVariable.environment)
    var variables: [SDEnvironmentVariable] = []
    
    init(name: String, isSelected: Bool = false) {
        self.id = UUID()
        self.name = name
        self.isSelected = isSelected
    }
}

@Model
final class SDEnvironmentVariable {
    @Attribute(.unique) var id: UUID
    var key: String
    var value: String
    var isSecret: Bool
    
    var environment: SDEnvironment?
    
    init(key: String, value: String, isSecret: Bool = false) {
        self.id = UUID()
        self.key = key
        self.value = value
        self.isSecret = isSecret
    }
}
