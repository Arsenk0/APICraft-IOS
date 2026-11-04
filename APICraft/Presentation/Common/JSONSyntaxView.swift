import SwiftUI

public struct JSONSyntaxView: View {
    let rawJSON: String
    @State private var isCopied = false
    
    public init(rawJSON: String) {
        self.rawJSON = rawJSON
    }
    
    private var formattedJSON: String {
        guard let data = rawJSON.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return rawJSON
        }
        return prettyString
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header bar inside card
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.red.opacity(0.8)).frame(width: 8, height: 8)
                    Circle().fill(Color.yellow.opacity(0.8)).frame(width: 8, height: 8)
                    Circle().fill(Color.green.opacity(0.8)).frame(width: 8, height: 8)
                    Text("JSON Response")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = formattedJSON
                    withAnimation {
                        isCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            isCopied = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Скопійовано" : "Копіювати")
                    }
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isCopied ? Color.green.opacity(0.15) : Color.primary.opacity(0.06))
                    .foregroundStyle(isCopied ? Color.green : Color.primary)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            
            Divider()
            
            // Text editor / viewer
            ScrollView([.horizontal, .vertical]) {
                Text(formattedJSON)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

