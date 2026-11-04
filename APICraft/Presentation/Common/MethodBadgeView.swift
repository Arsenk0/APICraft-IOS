import SwiftUI

public struct MethodBadgeView: View {
    let method: HTTPMethodType
    
    public init(method: HTTPMethodType) {
        self.method = method
    }
    
    public static func color(for method: HTTPMethodType) -> Color {
        switch method {
        case .get: return .blue
        case .post: return .green
        case .put: return .orange
        case .delete: return .red
        case .patch: return .purple
        case .head: return .teal
        case .options: return .indigo
        }
    }
    
    public var body: some View {
        Text(method.rawValue)
            .font(.caption2.bold().monospaced())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Self.color(for: method).opacity(0.12))
            .foregroundStyle(Self.color(for: method))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Self.color(for: method).opacity(0.25), lineWidth: 1)
            )
    }
}

