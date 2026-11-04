import Foundation
import SwiftData
import Observation

public enum RequestAuthType: String, CaseIterable, Identifiable {
    case none = "None"
    case bearer = "Bearer Token"
    case basic = "Basic Auth"
    case apiKey = "API Key"
    
    public var id: String { rawValue }
}

public enum APIKeyLocation: String, CaseIterable, Identifiable {
    case header = "Header"
    case query = "Query Param"
    
    public var id: String { rawValue }
}

@Observable
public final class RequestBuilderViewModel {
    public var title: String = ""
    public var url: String = "https://jsonplaceholder.typicode.com/todos/1"
    public var method: HTTPMethodType = .get
    public var bodyType: BodyType = .none
    public var bodyText: String = ""
    
    // Auth Settings
    public var authType: RequestAuthType = .none
    public var bearerToken: String = ""
    public var basicUsername: String = ""
    public var basicPassword: String = ""
    public var apiKeyName: String = "X-API-Key"
    public var apiKeyValue: String = ""
    public var apiKeyLocation: APIKeyLocation = .header
    
    public var headers: [RequestKeyValue] = [
        RequestKeyValue(key: "Accept", value: "application/json", isEnabled: true)
    ]
    public var queryParams: [RequestKeyValue] = []
    public var assertions: [RequestAssertionItem] = []
    
    public var isLoading: Bool = false
    public var response: NetworkResponse?
    public var assertionLogs: [AssertionEvaluationResult] = []
    
    public init() {}
    
    public func resetToNew() {
        self.title = ""
        self.url = "https://"
        self.method = .get
        self.bodyType = .none
        self.bodyText = ""
        self.authType = .none
        self.bearerToken = ""
        self.basicUsername = ""
        self.basicPassword = ""
        self.apiKeyName = "X-API-Key"
        self.apiKeyValue = ""
        self.apiKeyLocation = .header
        self.headers = [RequestKeyValue(key: "Accept", value: "application/json", isEnabled: true)]
        self.queryParams = []
        self.assertions = []
        self.response = nil
        self.assertionLogs = []
    }
    
    public func exportAsCURL() -> String {
        var effectiveHeaders = headers.map { (key: $0.key, value: $0.value, isEnabled: $0.isEnabled) }
        
        switch authType {
        case .none:
            break
        case .bearer:
            if !bearerToken.isEmpty {
                effectiveHeaders.append((key: "Authorization", value: "Bearer \(bearerToken)", isEnabled: true))
            }
        case .basic:
            let creds = "\(basicUsername):\(basicPassword)"
            if let data = creds.data(using: .utf8) {
                effectiveHeaders.append((key: "Authorization", value: "Basic \(data.base64EncodedString())", isEnabled: true))
            }
        case .apiKey:
            if !apiKeyName.isEmpty && !apiKeyValue.isEmpty && apiKeyLocation == .header {
                effectiveHeaders.append((key: apiKeyName, value: apiKeyValue, isEnabled: true))
            }
        }
        
        var effectiveURL = url
        if authType == .apiKey && apiKeyLocation == .query && !apiKeyName.isEmpty && !apiKeyValue.isEmpty {
            if var comps = URLComponents(string: effectiveURL) {
                var items = comps.queryItems ?? []
                items.append(URLQueryItem(name: apiKeyName, value: apiKeyValue))
                comps.queryItems = items
                effectiveURL = comps.string ?? effectiveURL
            }
        }
        
        return CURLGenerator.generate(
            url: effectiveURL,
            method: method,
            headers: effectiveHeaders,
            body: bodyText,
            bodyType: bodyType
        )
    }
    
    @discardableResult
    public func importFromCURL(_ curlString: String) -> Bool {
        guard let parsed = CURLParser.parse(curlString) else { return false }
        self.url = parsed.url
        self.method = parsed.method
        self.bodyType = parsed.bodyType
        self.bodyText = parsed.body ?? ""
        
        var remainingHeaders: [RequestKeyValue] = []
        self.authType = .none
        self.bearerToken = ""
        self.basicUsername = ""
        self.basicPassword = ""
        
        for h in parsed.headers {
            let keyLower = h.key.lowercased()
            if keyLower == "authorization" {
                if h.value.hasPrefix("Bearer ") {
                    self.authType = .bearer
                    self.bearerToken = String(h.value.dropFirst("Bearer ".count)).trimmingCharacters(in: .whitespaces)
                    continue
                } else if h.value.hasPrefix("Basic ") {
                    self.authType = .basic
                    let base64 = String(h.value.dropFirst("Basic ".count)).trimmingCharacters(in: .whitespaces)
                    if let decodedData = Data(base64Encoded: base64),
                       let decodedString = String(data: decodedData, encoding: .utf8) {
                        let parts = decodedString.components(separatedBy: ":")
                        if parts.count >= 2 {
                            self.basicUsername = parts[0]
                            self.basicPassword = parts.dropFirst().joined(separator: ":")
                        }
                    }
                    continue
                }
            }
            remainingHeaders.append(RequestKeyValue(key: h.key, value: h.value, isEnabled: true))
        }
        
        if !remainingHeaders.isEmpty {
            self.headers = remainingHeaders
        } else if self.authType != .none {
            self.headers = []
        }
        
        self.response = nil
        self.assertionLogs = []
        self.syncURLToParams()
        return true
    }
    
    public func resolveTitle() -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != "Untitled Request" {
            return trimmed
        }
        if let components = URLComponents(string: url), let host = components.host {
            let path = components.path
            if !path.isEmpty && path != "/" {
                return "\(host)\(path)"
            }
            return host
        }
        let cleaned = url
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "\(method.rawValue) Request" : cleaned
    }
    
    public func formatJSONBody() {
        guard !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let data = bodyText.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            self.bodyText = prettyString
        }
    }
    
    public func setJSONTemplate() {
        self.bodyType = .json
        if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.bodyText = "{\n  \"title\": \"sample\",\n  \"completed\": false\n}"
        }
    }
    
    public func syncParamsToURL() {
        guard var components = URLComponents(string: url) else { return }
        let activeParams = queryParams.filter { $0.isEnabled && !$0.key.isEmpty }
        if activeParams.isEmpty {
            components.queryItems = nil
        } else {
            components.queryItems = activeParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        if let newURL = components.string {
            self.url = newURL
        }
    }
    
    public func syncURLToParams() {
        guard let components = URLComponents(string: url), let items = components.queryItems, !items.isEmpty else { return }
        var newParams: [RequestKeyValue] = []
        for item in items {
            newParams.append(RequestKeyValue(key: item.name, value: item.value ?? "", isEnabled: true))
        }
        if !newParams.isEmpty {
            self.queryParams = newParams
        }
    }
    
    func sendRequest(context: ModelContext, activeEnv: SDEnvironment? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        var envMap: [String: String] = [:]
        if let env = activeEnv {
            for v in env.variables {
                envMap[v.key] = v.value
            }
        }
        
        let resolvedURL = VariableResolver.resolve(text: url, using: envMap)
        var resolvedHeaders: [String: String] = [:]
        for item in headers where item.isEnabled && !item.key.isEmpty {
            resolvedHeaders[item.key] = VariableResolver.resolve(text: item.value, using: envMap)
        }
        
        var queryItems: [URLQueryItem] = []
        for item in queryParams where item.isEnabled && !item.key.isEmpty {
            let resolvedVal = VariableResolver.resolve(text: item.value, using: envMap)
            queryItems.append(URLQueryItem(name: item.key, value: resolvedVal))
        }
        
        // Inject Auth Settings
        switch authType {
        case .none:
            break
        case .bearer:
            let trimmedToken = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedToken.isEmpty {
                let resolved = VariableResolver.resolve(text: trimmedToken, using: envMap)
                resolvedHeaders["Authorization"] = "Bearer \(resolved)"
            }
        case .basic:
            let resolvedUser = VariableResolver.resolve(text: basicUsername, using: envMap)
            let resolvedPass = VariableResolver.resolve(text: basicPassword, using: envMap)
            let credentials = "\(resolvedUser):\(resolvedPass)"
            if let credData = credentials.data(using: .utf8) {
                let base64 = credData.base64EncodedString()
                resolvedHeaders["Authorization"] = "Basic \(base64)"
            }
        case .apiKey:
            let trimmedKeyName = apiKeyName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedKeyVal = apiKeyValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKeyName.isEmpty && !trimmedKeyVal.isEmpty {
                let resolvedVal = VariableResolver.resolve(text: trimmedKeyVal, using: envMap)
                if apiKeyLocation == .header {
                    resolvedHeaders[trimmedKeyName] = resolvedVal
                } else {
                    queryItems.append(URLQueryItem(name: trimmedKeyName, value: resolvedVal))
                }
            }
        }
        
        let resolvedBody = VariableResolver.resolve(text: bodyText, using: envMap)
        
        let netResponse = await NativeNetworkClient.shared.execute(
            urlString: resolvedURL,
            method: method,
            headers: resolvedHeaders,
            queryItems: queryItems,
            body: resolvedBody,
            bodyType: bodyType
        )
        
        self.response = netResponse
        
        // Evaluate user-defined assertions dynamically (only if active assertions exist)
        var evalLogs: [AssertionEvaluationResult] = []
        let activeAssertions = assertions.filter { $0.isEnabled }
        for a in activeAssertions {
            let sdAssertion = SDTestAssertion(
                target: a.target,
                keyPath: a.keyPath,
                comparison: a.comparison,
                expectedValue: a.expectedValue,
                isEnabled: a.isEnabled
            )
            evalLogs.append(AssertionEngine.evaluate(assertion: sdAssertion, response: netResponse))
        }
        self.assertionLogs = evalLogs
        
        // Save to History in SwiftData with meaningful title & full headers/params
        let historyTitle = resolveTitle()
        let historyItem = SDRequest(
            title: historyTitle,
            urlTemplate: url,
            method: method,
            bodyType: bodyType,
            rawBodyContent: bodyText,
            isHistoryItem: true
        )
        
        for h in headers where !h.key.isEmpty {
            let p = SDRequestParameter(key: h.key, value: h.value, isEnabled: h.isEnabled, location: .header)
            historyItem.keyValues.append(p)
        }
        
        for q in queryParams where !q.key.isEmpty {
            let p = SDRequestParameter(key: q.key, value: q.value, isEnabled: q.isEnabled, location: .query)
            historyItem.keyValues.append(p)
        }
        
        for a in assertions {
            let p = SDTestAssertion(
                target: a.target,
                keyPath: a.keyPath,
                comparison: a.comparison,
                expectedValue: a.expectedValue,
                isEnabled: a.isEnabled
            )
            historyItem.assertions.append(p)
        }
        
        context.insert(historyItem)
        
        let allPassed = evalLogs.isEmpty ? true : evalLogs.allSatisfy { $0.isPassed }
        let execResult = SDExecutionResult(
            statusCode: netResponse.statusCode,
            responseDurationMs: netResponse.durationMs,
            responseBodySize: netResponse.sizeBytes,
            responseBody: netResponse.body,
            isAllAssertionsPassed: allPassed
        )
        execResult.request = historyItem
        context.insert(execResult)
        
        try? context.save()
    }
    
    func loadFrom(request: SDRequest) {
        self.title = request.title
        self.url = request.urlTemplate
        self.method = request.method
        self.bodyType = request.bodyType
        self.bodyText = request.rawBodyContent ?? ""
        
        let loadedHeaders = request.keyValues
            .filter { $0.location == .header }
            .map { RequestKeyValue(key: $0.key, value: $0.value, isEnabled: $0.isEnabled) }
        self.headers = loadedHeaders.isEmpty ? [RequestKeyValue(key: "Accept", value: "application/json", isEnabled: true)] : loadedHeaders
        
        self.queryParams = request.keyValues
            .filter { $0.location == .query }
            .map { RequestKeyValue(key: $0.key, value: $0.value, isEnabled: $0.isEnabled) }
        
        self.assertions = request.assertions.map {
            RequestAssertionItem(
                id: $0.id,
                target: $0.target,
                comparison: $0.comparison,
                expectedValue: $0.expectedValue,
                isEnabled: $0.isEnabled,
                keyPath: $0.keyPath
            )
        }
        
        self.response = nil
        self.assertionLogs = []
    }
    
    func saveToCollection(collection: SDCollection, customTitle: String?, context: ModelContext) {
        let trimmedCustom = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let reqTitle = trimmedCustom.isEmpty ? resolveTitle() : trimmedCustom
        
        let savedReq = SDRequest(
            title: reqTitle,
            urlTemplate: url,
            method: method,
            bodyType: bodyType,
            rawBodyContent: bodyText,
            isHistoryItem: false
        )
        savedReq.collection = collection
        
        for h in headers where !h.key.isEmpty {
            let p = SDRequestParameter(key: h.key, value: h.value, isEnabled: h.isEnabled, location: .header)
            savedReq.keyValues.append(p)
        }
        
        for q in queryParams where !q.key.isEmpty {
            let p = SDRequestParameter(key: q.key, value: q.value, isEnabled: q.isEnabled, location: .query)
            savedReq.keyValues.append(p)
        }
        
        for a in assertions {
            let p = SDTestAssertion(
                target: a.target,
                keyPath: a.keyPath,
                comparison: a.comparison,
                expectedValue: a.expectedValue,
                isEnabled: a.isEnabled
            )
            savedReq.assertions.append(p)
        }
        
        context.insert(savedReq)
        collection.requests.append(savedReq)
        try? context.save()
    }
}

// MARK: - Helper Models
@Observable
public final class RequestKeyValue: Identifiable {
    public let id: UUID
    public var key: String
    public var value: String
    public var isEnabled: Bool
    
    public init(id: UUID = UUID(), key: String, value: String, isEnabled: Bool = true) {
        self.id = id
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
    }
}

@Observable
public final class RequestAssertionItem: Identifiable {
    public let id: UUID
    public var target: AssertionTarget
    public var comparison: AssertionComparison
    public var expectedValue: String
    public var isEnabled: Bool
    public var keyPath: String?
    
    public init(
        id: UUID = UUID(),
        target: AssertionTarget = .statusCode,
        comparison: AssertionComparison = .equals,
        expectedValue: String = "200",
        isEnabled: Bool = true,
        keyPath: String? = nil
    ) {
        self.id = id
        self.target = target
        self.comparison = comparison
        self.expectedValue = expectedValue
        self.isEnabled = isEnabled
        self.keyPath = keyPath
    }
}
