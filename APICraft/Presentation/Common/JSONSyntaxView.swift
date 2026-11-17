import SwiftUI
import UIKit

public struct JSONSyntaxView: View {
    let rawJSON: String
    let formattedJSON: String
    let detectedFormat: String
    let lineCount: Int
    let isCollapsible: Bool
    
    @State private var isCopied = false
    @State private var wrapLines = true
    @State private var isExpanded = false
    @State private var isSearching = false
    @State private var searchText = ""
    
    public init(rawJSON: String) {
        self.rawJSON = rawJSON
        let trimmed = rawJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var fmt = "Raw"
        var pretty = rawJSON
        
        if trimmed.isEmpty {
            fmt = "Empty"
        } else if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            fmt = "JSON"
            if trimmed.utf8.count < 300_000,
               let data = trimmed.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                pretty = prettyString
            }
        } else if trimmed.lowercased().contains("<!doctype") || trimmed.lowercased().contains("<html") {
            fmt = "HTML"
        } else if trimmed.hasPrefix("<?xml") || (trimmed.hasPrefix("<") && trimmed.hasSuffix(">")) {
            fmt = "XML"
        }
        
        self.formattedJSON = pretty
        self.detectedFormat = fmt
        
        let count = pretty.components(separatedBy: .newlines).count
        self.lineCount = count
        self.isCollapsible = count > 12 || pretty.count > 350
    }
    
    private func countMatches(in text: String, query: String) -> Int {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return 0 }
        var count = 0
        var searchRange: Range<String.Index>? = text.startIndex..<text.endIndex
        while let range = searchRange, let found = text.range(of: cleanQuery, options: .caseInsensitive, range: range) {
            count += 1
            if found.upperBound >= text.endIndex || found.upperBound <= range.lowerBound {
                break
            }
            searchRange = found.upperBound..<text.endIndex
            if count > 500 { break }
        }
        return count
    }
    
    private func attributedContent(for text: String) -> AttributedString {
        var attr = AttributedString(text)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSearching, !query.isEmpty, text.count < 40_000 else { return attr }
        
        var searchRange = attr.startIndex..<attr.endIndex
        var iterations = 0
        while searchRange.lowerBound < searchRange.upperBound,
              let range = attr[searchRange].range(of: query, options: .caseInsensitive) {
            attr[range].backgroundColor = Color.yellow.opacity(0.35)
            attr[range].inlinePresentationIntent = .stronglyEmphasized
            
            iterations += 1
            if iterations > 200 || range.upperBound >= attr.endIndex || range.upperBound <= searchRange.lowerBound {
                break
            }
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
                        .keyboardType(.asciiCapable)
                    
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

// MARK: - Safe Non-Intrusive Keyboard Extensions
public extension View {
    /// Resigns the first responder to dismiss any active keyboard cleanly
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// Backward-compatible no-op that lets standard iOS touch handling and .scrollDismissesKeyboard work without touch theft
    func dismissKeyboardOnTap() -> some View {
        self
    }
}

// MARK: - Telegram-Style Keyboard Paste Accessory Bar
public struct TelegramKeyboardPasteBarView: View {
    public var onPaste: ((String) -> Void)? = nil
    @State private var hasClipboard: Bool = false
    @State private var hasURL: Bool = false
    
    public init(onPaste: ((String) -> Void)? = nil) {
        self.onPaste = onPaste
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            if hasClipboard {
                Button {
                    handlePaste()
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 26, height: 26)
                            Image(systemName: hasURL ? "safari.fill" : "doc.on.clipboard.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(hasURL ? "Paste URL" : "Paste from Clipboard")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            
                            Text(hasURL ? "Tap to insert URL" : "Tap to paste text")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .onAppear {
            checkClipboardSilently()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            checkClipboardSilently()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            checkClipboardSilently()
        }
    }
    
    /// Silently checks metadata without triggering the iOS 16+ "Allow Paste" alert
    private func checkClipboardSilently() {
        hasClipboard = UIPasteboard.general.hasStrings
        hasURL = UIPasteboard.general.hasURLs
    }
    
    private func handlePaste() {
        // Direct user tap: reading UIPasteboard.general.string is fully user-authorized
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        if let onPaste = onPaste {
            onPaste(text)
        } else {
            let handled = UIApplication.shared.sendAction(#selector(UIResponder.paste(_:)), to: nil, from: nil, for: nil)
            if !handled, let first = UIResponder.currentFirstKeyInput {
                first.insertText(text)
            }
        }
    }
}

public extension View {
    /// Safe no-op to allow native Apple keyboard accessories and edit menus
    func keyboardPasteBar(onPaste: ((String) -> Void)? = nil) -> some View {
        self
    }
}

public extension UIResponder {
    private weak static var _currentFirstResponder: UIResponder?
    
    static var currentFirstKeyInput: UIKeyInput? {
        _currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(findFirstResponder(_:)), to: nil, from: nil, for: nil)
        return _currentFirstResponder as? UIKeyInput
    }
    
    @objc private func findFirstResponder(_ sender: Any) {
        UIResponder._currentFirstResponder = self
    }
}
