import Foundation

public struct NetworkResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: String?
    public let durationMs: Double
    public let sizeBytes: Int
    public let error: String?
    
    public init(
        statusCode: Int,
        headers: [String: String],
        body: String?,
        durationMs: Double,
        sizeBytes: Int,
        error: String? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.durationMs = durationMs
        self.sizeBytes = sizeBytes
        self.error = error
    }
}
