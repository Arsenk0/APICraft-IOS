import Foundation
import SwiftData

@Model
final class SDRequestParameter {
    @Attribute(.unique) var id: UUID
    var key: String
    var value: String
    var isEnabled: Bool
    var location: ParameterLocation
    
    init(key: String, value: String, isEnabled: Bool = true, location: ParameterLocation) {
        self.id = UUID()
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
        self.location = location
    }
}
