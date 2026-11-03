import Foundation
import SwiftData

@Model
final class SDRequest {
    @Attribute(.unique) var id: UUID
    var title: String
    var urlTemplate: String
    var method: HTTPMethodType
    var bodyType: BodyType
    var rawBodyContent: String?
    var isHistoryItem: Bool
    var createdAt: Date
    
    var collection: SDCollection?
    
    @Relationship(deleteRule: .cascade)
    var keyValues: [SDRequestParameter] = []
    
    @Relationship(deleteRule: .cascade)
    var assertions: [SDTestAssertion] = []
    
    @Relationship(deleteRule: .cascade, inverse: \SDExecutionResult.request)
    var executionHistory: [SDExecutionResult] = []
    
    init(
        title: String,
        urlTemplate: String,
        method: HTTPMethodType = .get,
        bodyType: BodyType = .none,
        rawBodyContent: String? = nil,
        isHistoryItem: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.urlTemplate = urlTemplate
        self.method = method
        self.bodyType = bodyType
        self.rawBodyContent = rawBodyContent
        self.isHistoryItem = isHistoryItem
        self.createdAt = Date()
    }
}
