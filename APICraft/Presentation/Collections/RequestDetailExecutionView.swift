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
    
    public var body: some View {
        Form {
            Section("Request Setup") {
                HStack(spacing: 8) {
                    Picker("Method", selection: $request.method) {
                        ForEach(HTTPMethodType.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    
                    TextField("https://api.example.com", text: $request.urlTemplate)
                        .font(.system(size: 14, design: .monospaced))
                        .focused($isFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
                
                Button {
                    isFocused = false
                    Task {
                        await executeRequest()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isExecuting {
                            ProgressView()
                                .padding(.horizontal, 4)
                        } else {
                            Label("Execute Request", systemImage: "paperplane.fill")
                                .bold()
                        }
                        Spacer()
                    }
                }
                .disabled(isExecuting || request.urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            if let resp = lastResponse {
                Section("Execution Result") {
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
                    
                    if let body = resp.body, !body.isEmpty {
                        JSONSyntaxView(rawJSON: body)
                            .padding(.top, 4)
                    }
                }
            } else if let savedResult = request.executionHistory.sorted(by: { $0.executedAt > $1.executedAt }).first {
                Section("Saved Response from History") {
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
            
            Section("Parameters & Headers (\(request.keyValues.count))") {
                if request.keyValues.isEmpty {
                    Text("No parameters or headers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(request.keyValues) { kv in
                        HStack(spacing: 8) {
                            Text(kv.location.rawValue)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            Text(kv.key)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                            
                            Spacer(minLength: 4)
                            
                            Text(kv.value)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isFocused = false
                }
                .font(.body.bold())
            }
        }
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
        var headers: [String: String] = [:]
        var queryItems: [URLQueryItem] = []
        
        for kv in request.keyValues where kv.isEnabled && !kv.key.isEmpty {
            let resVal = VariableResolver.resolve(text: kv.value, using: envMap)
            if kv.location == .header {
                headers[kv.key] = resVal
            } else if kv.location == .query {
                queryItems.append(URLQueryItem(name: kv.key, value: resVal))
            }
        }
        
        let body = request.rawBodyContent.map { VariableResolver.resolve(text: $0, using: envMap) }
        
        let resp = await NativeNetworkClient.shared.execute(
            urlString: resolvedURL,
            method: request.method,
            headers: headers,
            queryItems: queryItems,
            body: body,
            bodyType: request.bodyType
        )
        
        self.lastResponse = resp
        
        let exec = SDExecutionResult(
            statusCode: resp.statusCode,
            responseDurationMs: resp.durationMs,
            responseBodySize: resp.sizeBytes,
            responseBody: resp.body,
            isAllAssertionsPassed: resp.statusCode >= 200 && resp.statusCode < 300
        )
        exec.request = request
        request.executionHistory.append(exec)
        modelContext.insert(exec)
        try? modelContext.save()
    }
}
