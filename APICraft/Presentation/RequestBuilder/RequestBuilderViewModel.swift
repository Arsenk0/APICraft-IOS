import Foundation
import SwiftData
import Observation

@Observable
public final class RequestBuilderViewModel {
    public var title: String = "Новий запит"
    public var url: String = "https://jsonplaceholder.typicode.com/todos/1"
    public var method: HTTPMethodType = .get
    public var bodyType: BodyType = .none
    public var bodyText: String = ""
    
    public var headers: [RequestKeyValue] = [
        RequestKeyValue(key: "Accept", value: "application/json", isEnabled: true)
    ]
    public var queryParams: [RequestKeyValue] = []
    
    public var isLoading: Bool = false
    public var response: NetworkResponse?
    public var assertionLogs: [AssertionEvaluationResult] = []
    
    public init() {}
    
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
        
        // Default assertions for demo
        let defaultAssertion = SDTestAssertion(
            target: .statusCode,
            comparison: .equals,
            expectedValue: "200"
        )
        let eval = AssertionEngine.evaluate(assertion: defaultAssertion, response: netResponse)
        self.assertionLogs = [eval]
        
        // Save to History in SwiftData
        let historyItem = SDRequest(
            title: title.isEmpty ? resolvedURL : title,
            urlTemplate: url,
            method: method,
            bodyType: bodyType,
            rawBodyContent: bodyText,
            isHistoryItem: true
        )
        context.insert(historyItem)
        
        let execResult = SDExecutionResult(
            statusCode: netResponse.statusCode,
            responseDurationMs: netResponse.durationMs,
            responseBodySize: netResponse.sizeBytes,
            responseBody: netResponse.body,
            isAllAssertionsPassed: eval.isPassed
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
        
        self.response = nil
        self.assertionLogs = []
    }
    
    func saveToCollection(collection: SDCollection, customTitle: String?, context: ModelContext) {
        let reqTitle = (customTitle?.isEmpty ?? true) ? (title.isEmpty ? url : title) : customTitle!
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
        
        context.insert(savedReq)
        collection.requests.append(savedReq)
        try? context.save()
    }
}

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
