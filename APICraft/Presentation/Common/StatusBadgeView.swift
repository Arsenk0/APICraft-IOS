import SwiftUI

extension Int {
    var httpStatusDescription: String {
        switch self {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 304: return "Not Modified"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 422: return "Unprocessable Entity"
        case 429: return "Too Many Requests"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        case 504: return "Gateway Timeout"
        default:
            switch self {
            case 200..<300: return "Success"
            case 300..<400: return "Redirect"
            case 400..<500: return "Client Error"
            case 500..<600: return "Server Error"
            default: return "Error"
            }
        }
    }
}

public struct StatusBadgeView: View {
    let statusCode: Int
    let showText: Bool
    
    public init(statusCode: Int, showText: Bool = false) {
        self.statusCode = statusCode
        self.showText = showText
    }
    
    private var badgeColor: Color {
        switch statusCode {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        case 500..<600: return .red
        default: return .gray
        }
    }
    
    private var iconName: String {
        switch statusCode {
        case 200..<300: return "checkmark.circle.fill"
        case 300..<400: return "arrow.triangle.turn.up.right.circle.fill"
        case 400..<500: return "exclamationmark.triangle.fill"
        case 500..<600: return "xmark.octagon.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .bold))
            
            Text(statusCode > 0 ? "\(statusCode)" : "ERR")
                .font(.caption.bold().monospacedDigit())
            
            if showText && statusCode > 0 {
                Text(statusCode.httpStatusDescription)
                    .font(.caption2.weight(.medium))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.12))
        .foregroundStyle(badgeColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(badgeColor.opacity(0.25), lineWidth: 1)
        )
    }
}
