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
            Section("Параметри виклику") {
                HStack {
                    Picker("Метод", selection: $request.method) {
                        ForEach(HTTPMethodType.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    
                    TextField("URL", text: $request.urlTemplate)
                        .focused($isFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
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
                            Label("Виконати запит", systemImage: "paperplane.fill")
                                .bold()
                        }
                        Spacer()
                    }
                }
                .disabled(isExecuting || request.urlTemplate.isEmpty)
            }
            
            if let resp = lastResponse {
                Section("Результат виконання") {
                    HStack {
                        StatusBadgeView(statusCode: resp.statusCode, showText: true)
                        Spacer()
                        Label(String(format: "%.0f ms", resp.durationMs), systemImage: "timer")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Label("\(resp.sizeBytes) B", systemImage: "arrow.down.circle")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    if let body = resp.body, !body.isEmpty {
                        JSONSyntaxView(rawJSON: body)
                            .padding(.top, 4)
                    }
                }
            } else if let savedResult = request.executionHistory.sorted(by: { $0.executedAt > $1.executedAt }).first {
                Section("Збережена відповідь з історії") {
                    HStack {
                        StatusBadgeView(statusCode: savedResult.statusCode, showText: true)
                        Spacer()
                        Label(String(format: "%.0f ms", savedResult.responseDurationMs), systemImage: "timer")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Label("\(savedResult.responseBodySize) B", systemImage: "arrow.down.circle")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    if let body = savedResult.responseBody, !body.isEmpty {
                        JSONSyntaxView(rawJSON: body)
                            .padding(.top, 4)
                    }
                }
            }
            
            Section("Параметри та Заголовки (\(request.keyValues.count))") {
                if request.keyValues.isEmpty {
                    Text("Параметри відсутні")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(request.keyValues) { kv in
                        HStack {
                            Text(kv.location.rawValue)
                                .font(.caption2.bold())
                                .padding(4)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Text(kv.key)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(kv.value)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            if !request.executionHistory.isEmpty {
                Section("Історія виконання (\(request.executionHistory.count))") {
                    ForEach(request.executionHistory.sorted(by: { $0.executedAt > $1.executedAt })) { hist in
                        HStack {
                            StatusBadgeView(statusCode: hist.statusCode)
                            Text(String(format: "%.0f ms", hist.responseDurationMs))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
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
                Button("Готово") {
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
