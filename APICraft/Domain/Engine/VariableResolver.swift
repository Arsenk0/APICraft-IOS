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

// MARK: - cURL Representation Models & Utilities
public struct ParsedCURLRequest {
    public var url: String
    public var method: HTTPMethodType
    public var headers: [(key: String, value: String)]
    public var body: String?
    public var bodyType: BodyType
    
    public init(
        url: String = "",
        method: HTTPMethodType = .get,
        headers: [(key: String, value: String)] = [],
        body: String? = nil,
        bodyType: BodyType = .none
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.bodyType = bodyType
    }
}

public struct CURLGenerator {
    public static func generate(
        url: String,
        method: HTTPMethodType,
        headers: [(key: String, value: String, isEnabled: Bool)],
        body: String?,
        bodyType: BodyType
    ) -> String {
        var lines: [String] = []
        
        // Base command with method
        lines.append("curl -X \(method.rawValue) \"\(url)\"")
        
        // Active Headers
        for h in headers where h.isEnabled && !h.key.isEmpty {
            let escapedVal = h.value.replacingOccurrences(of: "\"", with: "\\\"")
            lines.append("  -H \"\(h.key): \(escapedVal)\"")
        }
        
        // Body (if applicable)
        if let body = body, !body.isEmpty && bodyType != .none && method != .get && method != .head {
            let escapedBody = body.replacingOccurrences(of: "'", with: "'\\''")
            lines.append("  -d '\(escapedBody)'")
        }
        
        return lines.joined(separator: " \\\n")
    }
}

public struct CURLParser {
    public static func parse(_ command: String) -> ParsedCURLRequest? {
        var cleaned = command.trimmingCharacters(in: .whitespacesAndNewlines)
        // Handle backslash multiline wraps
        cleaned = cleaned.replacingOccurrences(of: "\\\n", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "\\\r\n", with: " ")
        
        guard cleaned.lowercased().hasPrefix("curl") else { return nil }
        
        var tokens = tokenize(cleaned)
        guard !tokens.isEmpty else { return nil }
        
        // Drop 'curl'
        if tokens.first?.lowercased() == "curl" {
            tokens.removeFirst()
        }
        
        var resultMethod: HTTPMethodType?
        var resultURL: String?
        var resultHeaders: [(key: String, value: String)] = []
        var resultBody: String?
        
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            
            if (token == "-X" || token == "--request") && index + 1 < tokens.count {
                index += 1
                let methodStr = tokens[index].uppercased()
                if let m = HTTPMethodType(rawValue: methodStr) {
                    resultMethod = m
                }
            } else if (token == "-H" || token == "--header") && index + 1 < tokens.count {
                index += 1
                let headerStr = tokens[index]
                if let colonIdx = headerStr.firstIndex(of: ":") {
                    let key = String(headerStr[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                    let val = String(headerStr[headerStr.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                    resultHeaders.append((key: key, value: val))
                }
            } else if (token == "-d" || token == "--data" || token == "--data-raw" || token == "--data-binary") && index + 1 < tokens.count {
                index += 1
                resultBody = tokens[index]
                if resultMethod == nil {
                    resultMethod = .post
                }
            } else if token.hasPrefix("http://") || token.hasPrefix("https://") {
                resultURL = token
            } else if !token.hasPrefix("-") && resultURL == nil {
                // Positional argument might be URL without protocol or with quotes stripped
                if token.contains(".") {
                    resultURL = token.hasPrefix("http") ? token : "https://" + token
                }
            }
            index += 1
        }
        
        guard let finalURL = resultURL else { return nil }
        let finalMethod = resultMethod ?? (resultBody != nil ? .post : .get)
        
        var inferredBodyType: BodyType = .none
        if let body = resultBody, !body.isEmpty {
            inferredBodyType = .json
        }
        
        return ParsedCURLRequest(
            url: finalURL,
            method: finalMethod,
            headers: resultHeaders,
            body: resultBody,
            bodyType: inferredBodyType
        )
    }
    
    // Command line tokenizer respecting single and double quotes
    private static func tokenize(_ command: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        var insideSingleQuote = false
        var insideDoubleQuote = false
        var isEscaped = false
        
        for char in command {
            if isEscaped {
                currentToken.append(char)
                isEscaped = false
                continue
            }
            
            if char == "\\" && !insideSingleQuote {
                isEscaped = true
                continue
            }
            
            if char == "'" && !insideDoubleQuote {
                insideSingleQuote.toggle()
                continue
            }
            
            if char == "\"" && !insideSingleQuote {
                insideDoubleQuote.toggle()
                continue
            }
            
            if char.isWhitespace && !insideSingleQuote && !insideDoubleQuote {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
            } else {
                currentToken.append(char)
            }
        }
        
        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }
        
        return tokens
    }
}
