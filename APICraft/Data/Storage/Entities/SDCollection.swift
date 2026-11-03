import Foundation
import SwiftData

@Model
final class SDCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var details: String?
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \SDRequest.collection)
    var requests: [SDRequest] = []
    
    init(name: String, details: String? = nil) {
        self.id = UUID()
        self.name = name
        self.details = details
        self.createdAt = Date()
        self.updatedAt = Date()
        self.requests = []
    }
}
