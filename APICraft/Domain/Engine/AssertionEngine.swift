import Foundation

public struct AssertionEvaluationResult: Identifiable {
    public let id = UUID()
    public let description: String
    public let isPassed: Bool
    public let failureReason: String?
}

public struct AssertionEngine {
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
                reason = "Очікувалось \(assertion.expectedValue), але отримано \(response.statusCode)"
            }
            
        case .responseTime:
            let expectedTime = Double(assertion.expectedValue) ?? 500.0
            desc = "Час відгуку \(assertion.comparison.rawValue) \(assertion.expectedValue) ms"
            switch assertion.comparison {
            case .lessThan:
                passed = response.durationMs < expectedTime
            case .greaterThan:
                passed = response.durationMs > expectedTime
            default:
                passed = response.durationMs <= expectedTime
            }
            if !passed {
                reason = "Отримано \(String(format: "%.1f", response.durationMs)) ms, що не задовольняє умову"
            }
            
        case .header:
            let headerName = assertion.keyPath ?? ""
            let headerVal = response.headers[headerName] ?? response.headers[headerName.lowercased()] ?? ""
            desc = "Заголовок [\(headerName)] \(assertion.comparison.rawValue) '\(assertion.expectedValue)'"
            switch assertion.comparison {
            case .equals:
                passed = headerVal == assertion.expectedValue
            case .contains:
                passed = headerVal.contains(assertion.expectedValue)
            default:
                passed = !headerVal.isEmpty
            }
            if !passed {
                reason = "Значення заголовка: '\(headerVal)'"
            }
            
        case .bodyContains:
            desc = "Тіло відповіді містить '\(assertion.expectedValue)'"
            let bodyText = response.body ?? ""
            passed = bodyText.contains(assertion.expectedValue)
            if !passed {
                reason = "Підрядок не знайдено у відповіді"
            }
        }
        
        return AssertionEvaluationResult(description: desc, isPassed: passed, failureReason: reason)
    }
}
