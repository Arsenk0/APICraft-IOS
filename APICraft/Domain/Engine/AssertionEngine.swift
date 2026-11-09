import Foundation

struct AssertionEvaluationResult: Identifiable {
    let id = UUID()
    let description: String
    let isPassed: Bool
    let failureReason: String?
    
    init(description: String, isPassed: Bool, failureReason: String? = nil) {
        self.description = description
        self.isPassed = isPassed
        self.failureReason = failureReason
    }
}

struct AssertionEngine {
    static func evaluate(
        assertion: SDTestAssertion,
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
            default:
                passed = response.durationMs <= expectedTime
            }
            if !passed {
                reason = "Received \(String(format: "%.1f", response.durationMs)) ms, failing condition"
            }
            
        case .header:
            let headerName = assertion.keyPath ?? ""
            let headerVal = response.headers[headerName] ?? response.headers[headerName.lowercased()] ?? ""
            desc = "Header [\(headerName)] \(assertion.comparison.rawValue) '\(assertion.expectedValue)'"
            switch assertion.comparison {
            case .equals:
                passed = headerVal == assertion.expectedValue
            case .contains:
                passed = headerVal.contains(assertion.expectedValue)
            default:
                passed = !headerVal.isEmpty
            }
            if !passed {
                reason = "Header value: '\(headerVal)'"
            }
            
        case .bodyContains:
            desc = "Response body contains '\(assertion.expectedValue)'"
            let bodyText = response.body ?? ""
            passed = bodyText.contains(assertion.expectedValue)
            if !passed {
                reason = "Substring not found in response"
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
    
    static func lookupJSONPath(in json: Any, path: String) -> Any? {
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
