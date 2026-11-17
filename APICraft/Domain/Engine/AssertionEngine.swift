import Foundation
import SwiftData

public protocol AssertionProtocol {
    var target: AssertionTarget { get }
    var keyPath: String? { get }
    var comparison: AssertionComparison { get }
    var expectedValue: String { get }
    var isEnabled: Bool { get }
}

public struct AssertionEvaluationResult: Identifiable {
    public let id = UUID()
    public let description: String
    public let isPassed: Bool
    public let failureReason: String?
    
    public init(description: String, isPassed: Bool, failureReason: String? = nil) {
        self.description = description
        self.isPassed = isPassed
        self.failureReason = failureReason
    }
}

public struct AssertionEngine {
    public static func evaluate(
        assertion: any AssertionProtocol,
        response: NetworkResponse
    ) -> AssertionEvaluationResult {
        let desc: String
        let passed: Bool
        var reason: String?
        
        switch assertion.target {
        case .statusCode:
            let expectedCode = Int(assertion.expectedValue) ?? 200
            desc = "Status code \(assertion.comparison.rawValue) \(assertion.expectedValue)"
            switch assertion.comparison {
            case .equals:
                passed = response.statusCode == expectedCode
            case .notEquals:
                passed = response.statusCode != expectedCode
            case .greaterThan:
                passed = response.statusCode > expectedCode
            case .lessThan:
                passed = response.statusCode < expectedCode
            default:
                passed = response.statusCode == expectedCode
            }
            if !passed {
                reason = "Expected \(assertion.expectedValue), but received \(response.statusCode)"
            }
            
        case .responseTime:
            let expectedTime = Double(assertion.expectedValue) ?? 500.0
            desc = "Response time \(assertion.comparison.rawValue) \(assertion.expectedValue) ms"
            switch assertion.comparison {
            case .lessThan:
                passed = response.durationMs < expectedTime
            case .greaterThan:
                passed = response.durationMs > expectedTime
            case .equals:
                passed = response.durationMs == expectedTime
            case .notEquals:
                passed = response.durationMs != expectedTime
            default:
                passed = response.durationMs <= expectedTime
            }
            if !passed {
                reason = "Received \(String(format: "%.1f", response.durationMs)) ms, failing condition"
            }
            
        case .header:
            let headerName = (assertion.keyPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? (assertion.keyPath ?? "")
                : ""
            let headerVal = response.headers.first(where: { $0.key.caseInsensitiveCompare(headerName) == .orderedSame })?.value ?? ""
            desc = "Header [\(headerName)] \(assertion.comparison.rawValue) '\(assertion.expectedValue)'"
            switch assertion.comparison {
            case .equals:
                passed = headerVal == assertion.expectedValue
            case .notEquals:
                passed = headerVal != assertion.expectedValue
            case .contains:
                passed = headerVal.localizedCaseInsensitiveContains(assertion.expectedValue) || headerVal.contains(assertion.expectedValue)
            case .regexMatch:
                passed = headerVal.range(of: assertion.expectedValue, options: .regularExpression) != nil
            default:
                passed = !headerVal.isEmpty
            }
            if !passed {
                reason = "Header value: '\(headerVal)'"
            }
            
        case .bodyContains:
            let bodyText = response.body ?? ""
            switch assertion.comparison {
            case .equals:
                desc = "Response body == '\(assertion.expectedValue)'"
                passed = bodyText == assertion.expectedValue
            case .notEquals:
                desc = "Response body != '\(assertion.expectedValue)'"
                passed = bodyText != assertion.expectedValue
            case .regexMatch:
                desc = "Response body matches regex '\(assertion.expectedValue)'"
                passed = bodyText.range(of: assertion.expectedValue, options: .regularExpression) != nil
            case .contains:
                fallthrough
            default:
                desc = "Response body contains '\(assertion.expectedValue)'"
                passed = bodyText.contains(assertion.expectedValue)
            }
            if !passed {
                reason = "Condition not met in response body"
            }
            
        case .jsonKeyExists:
            let key = (assertion.keyPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? (assertion.keyPath ?? "")
                : assertion.expectedValue
            desc = "JSON contains key '\(key)'"
            if let data = response.body?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                passed = lookupJSONPath(in: json, path: key) != nil
            } else {
                passed = false
            }
            if !passed {
                reason = "Key '\(key)' not found in JSON response"
            }
            
        case .jsonValue:
            let path = (assertion.keyPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? (assertion.keyPath ?? "")
                : "id"
            desc = "JSON [\(path)] \(assertion.comparison.rawValue) '\(assertion.expectedValue)'"
            if let data = response.body?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: []),
               let value = lookupJSONPath(in: json, path: path) {
                let actualString = "\(value)"
                switch assertion.comparison {
                case .equals:
                    passed = actualString == assertion.expectedValue
                case .notEquals:
                    passed = actualString != assertion.expectedValue
                case .contains:
                    passed = actualString.contains(assertion.expectedValue)
                case .regexMatch:
                    passed = actualString.range(of: assertion.expectedValue, options: .regularExpression) != nil
                case .greaterThan:
                    let actualNum = Double(actualString) ?? 0.0
                    let expNum = Double(assertion.expectedValue) ?? 0.0
                    passed = actualNum > expNum
                case .lessThan:
                    let actualNum = Double(actualString) ?? 0.0
                    let expNum = Double(assertion.expectedValue) ?? 0.0
                    passed = actualNum < expNum
                }
                if !passed {
                    reason = "Actual value was '\(actualString)'"
                }
            } else {
                passed = false
                reason = "Path '\(path)' not found in JSON body"
            }
        }
        
        return AssertionEvaluationResult(description: desc, isPassed: passed, failureReason: reason)
    }
    
    public static func evaluateOverallSuccess(
        evaluationResults: [AssertionEvaluationResult],
        statusCode: Int
    ) -> Bool {
        if evaluationResults.isEmpty {
            return statusCode >= 200 && statusCode < 400
        }
        return evaluationResults.allSatisfy { $0.isPassed }
    }
    
    public static func lookupJSONPath(in json: Any, path: String) -> Any? {
        let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanPath.isEmpty { return nil }
        
        // Normalize syntax like "users[0].name" -> "users.0.name"
        let normalized = cleanPath
            .replacingOccurrences(of: "[", with: ".")
            .replacingOccurrences(of: "]", with: "")
        let components = normalized.split(separator: ".").map(String.init)
        
        var current: Any? = json
        for comp in components {
            guard let cur = current else { return nil }
            if let dict = cur as? [String: Any] {
                current = dict[comp]
            } else if let array = cur as? [Any], let idx = Int(comp), idx >= 0, idx < array.count {
                current = array[idx]
            } else {
                return nil
            }
        }
        return current
    }
}

// MARK: - Centralized Request Execution Service (Clean Architecture / Use Case)
@MainActor
struct RequestExecutionService {
    @discardableResult
    static func execute(
        request: SDRequest,
        activeEnvironment: SDEnvironment?,
        context: ModelContext,
        recordHistoryCopy: Bool = true
    ) async -> (response: NetworkResponse, logs: [AssertionEvaluationResult], allPassed: Bool) {
        var envMap: [String: String] = [:]
        if let env = activeEnvironment {
            for v in env.variables {
                envMap[v.key] = v.value
            }
        }
        
        let resolvedURL = VariableResolver.resolve(text: request.urlTemplate, using: envMap)
        var reqHeaders: [String: String] = [:]
        var queryItems: [URLQueryItem] = []
        
        for kv in request.keyValues where kv.isEnabled && !kv.key.isEmpty {
            let resVal = VariableResolver.resolve(text: kv.value, using: envMap)
            if kv.location == .header {
                reqHeaders[kv.key] = resVal
            } else if kv.location == .query {
                queryItems.append(URLQueryItem(name: kv.key, value: resVal))
            }
        }
        
        let body = request.rawBodyContent.map { VariableResolver.resolve(text: $0, using: envMap) }
        
        let resp = await NativeNetworkClient.shared.execute(
            urlString: resolvedURL,
            method: request.method,
            headers: reqHeaders,
            queryItems: queryItems,
            body: body,
            bodyType: request.bodyType
        )
        
        var evalLogs: [AssertionEvaluationResult] = []
        for a in request.assertions where a.isEnabled {
            evalLogs.append(AssertionEngine.evaluate(assertion: a, response: resp))
        }
        
        let allPassed = AssertionEngine.evaluateOverallSuccess(
            evaluationResults: evalLogs,
            statusCode: resp.statusCode
        )
        let headersData = try? JSONSerialization.data(withJSONObject: resp.headers)
        
        let exec = SDExecutionResult(
            statusCode: resp.statusCode,
            responseDurationMs: resp.durationMs,
            responseBodySize: resp.sizeBytes,
            responseBody: resp.body,
            responseHeadersData: headersData,
            isAllAssertionsPassed: allPassed
        )
        exec.request = request
        request.executionHistory.append(exec)
        
        for log in evalLogs {
            let sLog = SDAssertionLog(
                assertionDescription: log.description,
                isPassed: log.isPassed,
                failureReason: log.failureReason
            )
            exec.assertionLogs.append(sLog)
        }
        
        if recordHistoryCopy && !request.isHistoryItem {
            let histTitle = request.title.hasPrefix("[Test]") ? request.title : request.title
            let histReq = SDRequest(
                title: histTitle,
                urlTemplate: request.urlTemplate,
                method: request.method,
                bodyType: request.bodyType,
                rawBodyContent: request.rawBodyContent,
                isHistoryItem: true
            )
            histReq.createdAt = Date()
            context.insert(histReq)
            
            for kv in request.keyValues {
                let p = SDRequestParameter(key: kv.key, value: kv.value, isEnabled: kv.isEnabled, location: kv.location)
                histReq.keyValues.append(p)
            }
            for a in request.assertions {
                let sa = SDTestAssertion(
                    target: a.target,
                    keyPath: a.keyPath,
                    comparison: a.comparison,
                    expectedValue: a.expectedValue,
                    isEnabled: a.isEnabled
                )
                histReq.assertions.append(sa)
            }
            
            let histExec = SDExecutionResult(
                statusCode: resp.statusCode,
                responseDurationMs: resp.durationMs,
                responseBodySize: resp.sizeBytes,
                responseBody: resp.body,
                responseHeadersData: headersData,
                isAllAssertionsPassed: allPassed
            )
            histExec.request = histReq
            histReq.executionHistory.append(histExec)
            
            for log in evalLogs {
                let sLog = SDAssertionLog(
                    assertionDescription: log.description,
                    isPassed: log.isPassed,
                    failureReason: log.failureReason
                )
                histExec.assertionLogs.append(sLog)
            }
        }
        
        try? context.save()
        return (resp, evalLogs, allPassed)
    }
}
