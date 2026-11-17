import Foundation

public struct ResponseCookie: Sendable, Identifiable {
    public var id: String { "\(name)_\(domain)_\(path)" }
    public let name: String
    public let value: String
    public let domain: String
    public let path: String
    public let expiresDate: Date?
    public let isSecure: Bool
    public let isHTTPOnly: Bool
    
    public init(
        name: String,
        value: String,
        domain: String,
        path: String = "/",
        expiresDate: Date? = nil,
        isSecure: Bool = false,
        isHTTPOnly: Bool = false
    ) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expiresDate = expiresDate
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
    }
}

public struct NetworkResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let cookies: [ResponseCookie]
    public let body: String?
    public let durationMs: Double
    public let sizeBytes: Int
    public let error: String?
    
    public init(
        statusCode: Int,
        headers: [String: String],
        cookies: [ResponseCookie] = [],
        body: String?,
        durationMs: Double,
        sizeBytes: Int,
        error: String? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.cookies = cookies
        self.body = body
        self.durationMs = durationMs
        self.sizeBytes = sizeBytes
        self.error = error
    }
}

// MARK: - Clipboard Preview & Parser Domain Model
public struct ClipboardPreviewInfo: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let iconName: String
    public let rawText: String
    
    public init(title: String, subtitle: String, iconName: String, rawText: String) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.rawText = rawText
    }
    
    public static func make(from text: String) -> ClipboardPreviewInfo? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), (scheme == "http" || scheme == "https"), let host = url.host {
            let cleanHost = host.replacingOccurrences(of: "www.", with: "")
            let sub: String
            if cleanHost.contains("tiktok") {
                sub = "Paste from TikTok"
            } else if cleanHost.contains("github") {
                sub = "Paste from GitHub"
            } else if cleanHost.contains("google") {
                sub = "Paste from Google"
            } else if cleanHost.contains("typicode") {
                sub = "Paste from Typicode"
            } else {
                sub = "Paste URL"
            }
            return ClipboardPreviewInfo(title: cleanHost, subtitle: sub, iconName: "safari.fill", rawText: trimmed)
        } else if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            let oneLine = trimmed.replacingOccurrences(of: "\n", with: " ")
            let display = oneLine.count > 24 ? String(oneLine.prefix(24)) + "..." : oneLine
            return ClipboardPreviewInfo(title: display, subtitle: "Paste JSON", iconName: "curlybraces", rawText: trimmed)
        } else if trimmed.lowercased().hasPrefix("curl ") {
            return ClipboardPreviewInfo(title: "cURL Command", subtitle: "Paste cURL", iconName: "terminal.fill", rawText: trimmed)
        } else {
            let oneLine = trimmed.replacingOccurrences(of: "\n", with: " ")
            let display = oneLine.count > 24 ? String(oneLine.prefix(24)) + "..." : oneLine
            return ClipboardPreviewInfo(title: display, subtitle: "Paste from Clipboard", iconName: "doc.on.clipboard.fill", rawText: trimmed)
        }
    }
}
