import SwiftUI

public struct JSONSyntaxView: View {
    let rawJSON: String
    @State private var isCopied = false
    @State private var wrapLines = true
    @State private var isExpanded = false
    
    public init(rawJSON: String) {
        self.rawJSON = rawJSON
    }
    
    private var detectedFormat: String {
        let trimmed = rawJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Empty" }
        if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) && formattedJSON != rawJSON {
            return "JSON"
        }
        if trimmed.lowercased().contains("<!doctype") || trimmed.lowercased().contains("<html") {
            return "HTML"
        }
        if trimmed.hasPrefix("<?xml") || (trimmed.hasPrefix("<") && trimmed.hasSuffix(">")) {
            return "XML"
        }
        return "Raw"
    }
    
    private var formattedJSON: String {
        let trimmed = rawJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return rawJSON
        }
        return prettyString
    }
    
    private var lineCount: Int {
        formattedJSON.components(separatedBy: .newlines).count
    }
    
    private var isCollapsible: Bool {
        lineCount > 12 || formattedJSON.count > 350
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header bar inside card
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle().fill(Color.red.opacity(0.8)).frame(width: 7, height: 7)
                    Circle().fill(Color.yellow.opacity(0.8)).frame(width: 7, height: 7)
                    Circle().fill(Color.green.opacity(0.8)).frame(width: 7, height: 7)
                    Text("\(detectedFormat) Body")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 3)
                    
                    if lineCount > 1 {
                        Text("• \(lineCount) lines")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                if !rawJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Line wrap toggle
                    Button {
                        withAnimation {
                            wrapLines.toggle()
                        }
                    } label: {
                        Text(wrapLines ? "Wrap: On" : "Wrap: Off")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    // Expand/Collapse icon toggle if body is large
                    if isCollapsible {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                                .padding(5)
                                .background(Color.primary.opacity(0.06))
                                .foregroundStyle(.secondary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Copy button
                    Button {
                        UIPasteboard.general.string = formattedJSON
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                            Text(isCopied ? "Copied" : "Copy")
                        }
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isCopied ? Color.green.opacity(0.15) : Color.primary.opacity(0.06))
                        .foregroundStyle(isCopied ? Color.green : Color.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            
            Divider()
            
            // Response Content
            let trimmed = formattedJSON.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Response body is empty")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("The server returned no body content (e.g. 204 No Content or redirect).")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        Group {
                            if wrapLines {
                                Text(trimmed)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(12)
                                    .textSelection(.enabled)
                            } else {
                                ScrollView(.horizontal, showsIndicators: true) {
                                    Text(trimmed)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .padding(12)
                                        .textSelection(.enabled)
                                }
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                        .frame(maxHeight: (isCollapsible && !isExpanded) ? 180 : nil, alignment: .topLeading)
                        .clipped()
                        
                        // Subtle gradient shadow when collapsed
                        if isCollapsible && !isExpanded {
                            LinearGradient(
                                colors: [Color(.secondarySystemBackground).opacity(0), Color(.secondarySystemBackground)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 50)
                            .allowsHitTesting(false)
                        }
                    }
                    
                    // Expand / Collapse Bottom Bar
                    if isCollapsible {
                        Divider()
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption2.bold())
                                Text(isExpanded ? "Collapse Body" : "Expand Full Body (\(lineCount) lines)")
                                    .font(.caption.bold())
                            }
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemBackground).opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
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
