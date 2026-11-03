import Foundation

public struct VariableResolver {
    public static func resolve(text: String, using variables: [String: String]) -> String {
        guard !variables.isEmpty else { return text }
        var result = text
        for (key, val) in variables {
            let placeholder = "{{" + key + "}}"
            result = result.replacingOccurrences(of: placeholder, with: val)
        }
        return result
    }
}
