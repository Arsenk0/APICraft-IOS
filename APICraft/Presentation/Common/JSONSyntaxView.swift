import SwiftUI

public struct JSONSyntaxView: View {
    let rawJSON: String
    @State private var isCopied = false
    @State private var wrapLines = true
    @State private var isExpanded = false
    @State private var isSearching = false
    @State private var searchText = ""
    
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
    
    private func countMatches(in text: String, query: String) -> Int {
        guard !query.isEmpty else { return 0 }
        var count = 0
        var searchRange: Range<String.Index>? = text.startIndex..<text.endIndex
        while let range = searchRange, let found = text.range(of: query, options: .caseInsensitive, range: range) {
            count += 1
            searchRange = found.upperBound < text.endIndex ? found.upperBound..<text.endIndex : nil
        }
        return count
    }
    
    private func attributedContent(for text: String) -> AttributedString {
        var attr = AttributedString(text)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSearching, !query.isEmpty else { return attr }
        
        var searchRange = attr.startIndex..<attr.endIndex
        while let range = attr[searchRange].range(of: query, options: .caseInsensitive) {
            attr[range].backgroundColor = Color.yellow.opacity(0.35)
            attr[range].inlinePresentationIntent = .stronglyEmphasized
            searchRange = range.upperBound..<attr.endIndex
        }
        return attr
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
                    // In-body Search toggle
                    Button {
                        withAnimation {
                            isSearching.toggle()
                            if isSearching {
                                isExpanded = true
                            } else {
                                searchText = ""
                            }
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10, weight: .bold))
                            .padding(5)
                            .background(isSearching ? Color.blue.opacity(0.15) : Color.primary.opacity(0.06))
                            .foregroundStyle(isSearching ? Color.blue : Color.secondary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
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
            
            // Search Input Row
            if isSearching {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("Find in response body...", text: $searchText)
                        .font(.system(size: 12, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    if !searchText.isEmpty {
                        let matches = countMatches(in: formattedJSON, query: searchText)
                        Text("\(matches) match\(matches == 1 ? "" : "es")")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(matches > 0 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .foregroundStyle(matches > 0 ? Color.green : Color.orange)
                            .clipShape(Capsule())
                        
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                
                Divider()
            } else {
                Divider()
            }
            
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
                                Text(attributedContent(for: trimmed))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(12)
                                    .textSelection(.enabled)
                            } else {
                                ScrollView(.horizontal, showsIndicators: true) {
                                    Text(attributedContent(for: trimmed))
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
                                colors: [
                                    Color(.systemBackground).opacity(0),
                                    Color(.systemBackground).opacity(0.85),
                                    Color(.systemBackground)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 48)
                            .allowsHitTesting(false)
                        }
                    }
                    
                    // Show More / Show Less Button
                    if isCollapsible {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isExpanded ? "Show Less" : "Show Full Content (\(lineCount) lines)")
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.03))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
