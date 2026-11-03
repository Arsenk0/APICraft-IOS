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
}

public struct RequestKeyValue: Identifiable {
    public let id = UUID()
    public var key: String
    public var value: String
    public var isEnabled: Bool
}
