import SwiftUI

public struct StatusBadgeView: View {
    let statusCode: Int
    
    public init(statusCode: Int) {
        self.statusCode = statusCode
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
    
    public var body: some View {
        Text(statusCode > 0 ? "\(statusCode)" : "ERR")
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }
}
