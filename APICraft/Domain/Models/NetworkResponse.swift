import Foundation

public struct ResponseCookie: Sendable, Identifiable {
    public var id: String { "\(name)_\(domain)_\(path)" }
    public let name: String
    public let value: String
    public let domain: String
    public let path: String
    public let expiresDate: Date?
    public let isSecure: Bool
    public let isHTTPOnly: Bool
    
    public init(
        name: String,
        value: String,
        domain: String,
        path: String = "/",
        expiresDate: Date? = nil,
        isSecure: Bool = false,
        isHTTPOnly: Bool = false
    ) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expiresDate = expiresDate
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
    }
}

public struct NetworkResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let cookies: [ResponseCookie]
    public let body: String?
    public let durationMs: Double
    public let sizeBytes: Int
    public let error: String?
    
    public init(
        statusCode: Int,
        headers: [String: String],
        cookies: [ResponseCookie] = [],
        body: String?,
        durationMs: Double,
        sizeBytes: Int,
        error: String? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.cookies = cookies
        self.body = body
        self.durationMs = durationMs
        self.sizeBytes = sizeBytes
        self.error = error
    }
}
