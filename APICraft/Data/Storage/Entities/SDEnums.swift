import Foundation

public enum HTTPMethodType: String, Codable, CaseIterable, Identifiable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"
    case options = "OPTIONS"
    
    public var id: String { rawValue }
}

public enum BodyType: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case json = "JSON"
    case formData = "Form Data"
    case urlEncoded = "x-www-form-urlencoded"
    
    public var id: String { rawValue }
}

public enum AssertionComparison: String, Codable, CaseIterable, Identifiable {
    case equals = "=="
    case notEquals = "!="
    case contains = "Містить"
    case greaterThan = ">"
    case lessThan = "<"
    
    public var id: String { rawValue }
}

public enum AssertionTarget: String, Codable, CaseIterable, Identifiable {
    case statusCode = "Status Code"
    case responseTime = "Час відгуку (ms)"
    case header = "Header"
    case bodyContains = "Тіло містить текст"
    
    public var id: String { rawValue }
}

public enum ParameterLocation: String, Codable, CaseIterable, Identifiable {
    case header = "Header"
    case query = "Query"
    case formField = "Form Field"
    
    public var id: String { rawValue }
}
