import Foundation
import SwiftData
import Observation

@Observable
public final class RequestBuilderViewModel {
    public var title: String = ""
    public var url: String = "https://jsonplaceholder.typicode.com/todos/1"
    public var method: HTTPMethodType = .get
    public var bodyType: BodyType = .none
    public var bodyText: String = ""
    
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
        self.headers = [RequestKeyValue(key: "Accept", value: "application/json", isEnabled: true)]
        self.queryParams = []
        self.assertions = []
        self.response = nil
        self.assertionLogs = []
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
