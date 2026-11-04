import SwiftUI
import SwiftData

struct RequestDetailExecutionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SDEnvironment> { $0.isSelected }) private var activeEnvironments: [SDEnvironment]
    
    @Bindable var request: SDRequest
    @State private var isExecuting = false
    @State private var lastResponse: NetworkResponse?
    @FocusState private var isFocused: Bool
    
    init(request: SDRequest) {
        self.request = request
    }
    
    private var headers: [SDRequestParameter] {
        request.keyValues.filter { $0.location == .header }
    }
    
    private var queryParams: [SDRequestParameter] {
        request.keyValues.filter { $0.location == .query }
    }
    
    public var body: some View {
        Form {
            Section("Request") {
                HStack(alignment: .top, spacing: 10) {
                    if request.isHistoryItem {
                        // Fixed method badge for history items (cannot be edited)
                        MethodBadgeView(method: request.method)
                            .padding(.top, 4)
                    } else {
                        Picker("Method", selection: $request.method) {
                            ForEach(HTTPMethodType.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .padding(.top, 2)
                    }
                    
                    TextField("https://api.example.com", text: $request.urlTemplate, axis: .vertical)
                        .font(.system(size: 14, design: .monospaced))
                        .focused($isFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        .lineLimit(1...3)
                }
                
                VStack(spacing: 8) {
                    Button {
                        isFocused = false
                        Task {
                            await executeRequest()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isExecuting {
                                ProgressView()
                                    .tint(.white)
                            } else if request.executionHistory.isEmpty && lastResponse == nil {
                                Image(systemName: "paperplane.fill")
                                Text("Send Request")
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text("Send Again")
                            }
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.blue.opacity(0.2), radius: 3, y: 2)
                    }
                    .disabled(isExecuting || request.urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.plain)
                    
                    Button {
                        AppNavigationState.shared.openInBuilder(request: request)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open in Request Builder")
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.06))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .listRowSeparator(.hidden)
                .padding(.vertical, 4)
            }
            
            // Execution Result
            if let resp = lastResponse {
                Section("Latest Response") {
                    HStack(spacing: 8) {
                        StatusBadgeView(statusCode: resp.statusCode, showText: true)
                        Spacer(minLength: 4)
                        Label(String(format: "%.0f ms", resp.durationMs), systemImage: "timer")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Label("\(resp.sizeBytes) B", systemImage: "arrow.down.circle")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let err = resp.error {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    JSONSyntaxView(rawJSON: resp.body ?? "")
                        .padding(.top, 4)
                }
            } else if let savedResult = request.executionHistory.sorted(by: { $0.executedAt > $1.executedAt }).first {
                Section("Saved Response") {
                    HStack(spacing: 8) {
                        StatusBadgeView(statusCode: savedResult.statusCode, showText: true)
                        Spacer(minLength: 4)
                        Label(String(format: "%.0f ms", savedResult.responseDurationMs), systemImage: "timer")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Label("\(savedResult.responseBodySize) B", systemImage: "arrow.down.circle")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let body = savedResult.responseBody, !body.isEmpty {
                        JSONSyntaxView(rawJSON: body)
                            .padding(.top, 4)
                    }
                }
            }
            
            // Headers Section
            Section("Headers (\(headers.count))") {
                if headers.isEmpty {
                    Text("No headers configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(headers) { h in
                        HStack(spacing: 8) {
                            Text(h.key)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(h.isEnabled ? .primary : .secondary)
                                .lineLimit(1)
                            
                            Spacer(minLength: 4)
                            
                            Text(h.value)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            // Query Parameters Section
            Section("Query Parameters (\(queryParams.count))") {
                if queryParams.isEmpty {
                    Text("No query parameters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(queryParams) { q in
                        HStack(spacing: 8) {
                            Text(q.key)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(q.isEnabled ? .primary : .secondary)
                                .lineLimit(1)
                            
                            Spacer(minLength: 4)
                            
                            Text(q.value)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            // Body Section (if present)
            if let body = request.rawBodyContent, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Body (\(request.bodyType.rawValue))") {
                    Text(body)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            if !request.executionHistory.isEmpty {
                Section("Execution History (\(request.executionHistory.count))") {
                    ForEach(request.executionHistory.sorted(by: { $0.executedAt > $1.executedAt })) { hist in
                        HStack(spacing: 8) {
                            StatusBadgeView(statusCode: hist.statusCode)
                            Text(String(format: "%.0f ms", hist.responseDurationMs))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 4)
                            Text(hist.executedAt.formatted(date: .omitted, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(request.title)
        .scrollDismissesKeyboard(.interactively)
    }
    
    private func executeRequest() async {
        isExecuting = true
        defer { isExecuting = false }
        
        var envMap: [String: String] = [:]
        if let env = activeEnvironments.first {
            for v in env.variables {
                envMap[v.key] = v.value
            }
        }
        
        let resolvedURL = VariableResolver.resolve(text: request.urlTemplate, using: envMap)
        var reqHeaders: [String: String] = [:]
        var queryItems: [URLQueryItem] = []
        
        for kv in request.keyValues where kv.isEnabled && !kv.key.isEmpty {
            let resVal = VariableResolver.resolve(text: kv.value, using: envMap)
            if kv.location == .header {
                reqHeaders[kv.key] = resVal
            } else if kv.location == .query {
                queryItems.append(URLQueryItem(name: kv.key, value: resVal))
            }
        }
        
        let body = request.rawBodyContent.map { VariableResolver.resolve(text: $0, using: envMap) }
        
        let resp = await NativeNetworkClient.shared.execute(
            urlString: resolvedURL,
            method: request.method,
            headers: reqHeaders,
            queryItems: queryItems,
            body: body,
            bodyType: request.bodyType
        )
        
        self.lastResponse = resp
        
        // Save execution to SwiftData
        let exec = SDExecutionResult(
            statusCode: resp.statusCode,
            responseDurationMs: resp.durationMs,
            responseBodySize: resp.sizeBytes,
            responseBody: resp.body,
            isAllAssertionsPassed: resp.statusCode >= 200 && resp.statusCode < 400
        )
        exec.request = request
        modelContext.insert(exec)
        request.executionHistory.append(exec)
        try? modelContext.save()
    }
}
