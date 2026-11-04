import Foundation

public actor NativeNetworkClient {
    public static let shared = NativeNetworkClient()
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
    }
    
    public func execute(
        urlString: String,
        method: HTTPMethodType,
        headers: [String: String],
        queryItems: [URLQueryItem],
        body: String?,
        bodyType: BodyType
    ) async -> NetworkResponse {
        var sanitizedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sanitizedURLString.isEmpty && !sanitizedURLString.lowercased().hasPrefix("http://") && !sanitizedURLString.lowercased().hasPrefix("https://") {
            sanitizedURLString = "https://" + sanitizedURLString
        }
        
        guard var components = URLComponents(string: sanitizedURLString) else {
            return NetworkResponse(statusCode: 0, headers: [:], body: nil, durationMs: 0, sizeBytes: 0, error: "Invalid URL format")
        }
        
        if !queryItems.isEmpty {
            var existingItems = components.queryItems ?? []
            existingItems.append(contentsOf: queryItems)
            components.queryItems = existingItems
        }
        
        guard let url = components.url else {
            return NetworkResponse(statusCode: 0, headers: [:], body: nil, durationMs: 0, sizeBytes: 0, error: "Unable to construct valid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        
        if method != .get && method != .head, let body = body, !body.isEmpty {
            request.httpBody = body.data(using: .utf8)
            if bodyType == .json && request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (data, response) = try await session.data(for: request)
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return NetworkResponse(statusCode: 0, headers: [:], body: nil, durationMs: duration, sizeBytes: data.count, error: "Invalid server response type")
            }
            
            var respHeaders: [String: String] = [:]
            for (key, val) in httpResponse.allHeaderFields {
                respHeaders[String(describing: key)] = String(describing: val)
            }
            
            let bodyString = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            
            return NetworkResponse(
                statusCode: httpResponse.statusCode,
                headers: respHeaders,
                body: bodyString,
                durationMs: duration,
                sizeBytes: data.count
            )
        } catch {
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            return NetworkResponse(
                statusCode: 0,
                headers: [:],
                body: nil,
                durationMs: duration,
                sizeBytes: 0,
                error: error.localizedDescription
            )
        }
    }
}
