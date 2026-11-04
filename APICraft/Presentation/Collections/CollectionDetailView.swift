import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var collection: SDCollection
    
    @State private var showingAddRequestAlert = false
    @State private var showingRunnerSheet = false
    @State private var newRequestTitle = ""
    @State private var newRequestURL = "https://"
    @State private var newRequestMethod: HTTPMethodType = .get
    
    init(collection: SDCollection) {
        self.collection = collection
    }
    
    public var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(collection.name)
                        .font(.title3.bold())
                        .lineLimit(2)
                    if let details = collection.details, !details.isEmpty {
                        Text(details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Created: \(collection.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            
            // Run Collection Hero Action
            if !collection.requests.isEmpty {
                Section {
                    Button {
                        showingRunnerSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.subheadline.bold())
                            Text("Run Collection (\(collection.requests.count) \(collection.requests.count == 1 ? "request" : "requests"))")
                                .font(.subheadline.bold())
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.blue.opacity(0.3), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            
            Section("Saved Requests (\(collection.requests.count))") {
                if collection.requests.isEmpty {
                    ContentUnavailableView(
                        "No Requests",
                        systemImage: "paperplane",
                        description: Text("Save requests from the 'Requests' tab or tap + to create one.")
                    )
                } else {
                    ForEach(collection.requests) { request in
                        NavigationLink {
                            RequestDetailExecutionView(request: request)
                        } label: {
                            HStack(spacing: 10) {
                                MethodBadgeView(method: request.method)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(request.title)
                                        .font(.subheadline.bold())
                                        .lineLimit(1)
                                    Text(request.urlTemplate)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer(minLength: 4)
                                
                                if let lastResult = request.executionHistory.last {
                                    StatusBadgeView(statusCode: lastResult.statusCode)
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                AppNavigationState.shared.openInBuilder(request: request)
                            } label: {
                                Label("Open in Builder", systemImage: "arrow.up.right.square")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete(perform: deleteRequest)
                }
            }
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !collection.requests.isEmpty {
                    Button {
                        showingRunnerSheet = true
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                
                Button {
                    newRequestTitle = ""
                    newRequestURL = "https://"
                    newRequestMethod = .get
                    showingAddRequestAlert = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showingAddRequestAlert) {
            newRequestSheet
        }
        .sheet(isPresented: $showingRunnerSheet) {
            CollectionRunnerView(collection: collection)
        }
    }
    
    private func deleteRequest(offsets: IndexSet) {
        for index in offsets {
            let req = collection.requests[index]
            modelContext.delete(req)
        }
        try? modelContext.save()
    }
    
    private var newRequestSheet: some View {
        NavigationStack {
            Form {
                Section("Request Details") {
                    TextField("Title (e.g. Get User)", text: $newRequestTitle)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                    
                    Picker("Method", selection: $newRequestMethod) {
                        ForEach(HTTPMethodType.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    
                    TextField("URL", text: $newRequestURL, axis: .vertical)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                }
            }
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddRequestAlert = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmedTitle = newRequestTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        let title = trimmedTitle.isEmpty ? "\(newRequestMethod.rawValue) Request" : trimmedTitle
                        let newReq = SDRequest(
                            title: title,
                            urlTemplate: newRequestURL,
                            method: newRequestMethod,
                            bodyType: .none,
                            rawBodyContent: nil,
                            isHistoryItem: false
                        )
                        newReq.collection = collection
                        modelContext.insert(newReq)
                        collection.requests.append(newReq)
                        try? modelContext.save()
                        showingAddRequestAlert = false
                    }
                    .disabled(newRequestURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Collection Runner View
struct RunnerItemResult: Identifiable {
    let id = UUID()
    let request: SDRequest
    let statusCode: Int
    let durationMs: Double
    let sizeBytes: Int
    let assertionLogs: [AssertionEvaluationResult]
    let isAllPassed: Bool
    let error: String?
}

struct CollectionRunnerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<SDEnvironment> { $0.isSelected }) private var activeEnvironments: [SDEnvironment]
    
    let collection: SDCollection
    
    @State private var isRunning = false
    @State private var currentIndex = 0
    @State private var results: [RunnerItemResult] = []
    @State private var hasFinished = false
    
    init(collection: SDCollection) {
        self.collection = collection
    }
    
    private var totalPassedAssertions: Int {
        results.reduce(0) { sum, r in sum + r.assertionLogs.filter { $0.isPassed }.count }
    }
    
    private var totalAssertions: Int {
        results.reduce(0) { sum, r in sum + r.assertionLogs.count }
    }
    
    private var avgLatency: Double {
        guard !results.isEmpty else { return 0 }
        let total = results.reduce(0.0) { $0 + $1.durationMs }
        return total / Double(results.count)
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header Status Card
                    VStack(spacing: 12) {
                        if isRunning {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Executing Requests...")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text("\(currentIndex + 1) of \(collection.requests.count)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                
                                ProgressView(value: Double(currentIndex + 1), total: Double(max(1, collection.requests.count)))
                                    .tint(.blue)
                                
                                if currentIndex < collection.requests.count {
                                    HStack(spacing: 6) {
                                        MethodBadgeView(method: collection.requests[currentIndex].method)
                                        Text(collection.requests[currentIndex].title)
                                            .font(.caption.bold())
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        } else if hasFinished {
                            // Completion Summary Dashboard
                            VStack(spacing: 10) {
                                HStack {
                                    Image(systemName: results.allSatisfy { $0.isAllPassed } ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                        .foregroundStyle(results.allSatisfy { $0.isAllPassed } ? .green : .orange)
                                        .font(.title2)
                                    Text("Run Finished")
                                        .font(.headline.bold())
                                    Spacer()
                                }
                                
                                HStack(spacing: 8) {
                                    summaryCard(title: "Requests", value: "\(results.count)", subtitle: "completed", color: .blue)
                                    summaryCard(
                                        title: "Assertions",
                                        value: "\(totalPassedAssertions)/\(totalAssertions)",
                                        subtitle: totalAssertions == 0 ? "none" : (totalPassedAssertions == totalAssertions ? "100% pass" : "issues"),
                                        color: totalPassedAssertions == totalAssertions ? .green : .red
                                    )
                                    summaryCard(title: "Avg Time", value: String(format: "%.0f ms", avgLatency), subtitle: "latency", color: .purple)
                                }
                            }
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "play.circle")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.blue)
                                Text("Ready to test \(collection.requests.count) requests")
                                    .font(.headline)
                                Text("Collection Runner will automatically execute all requests sequentially and evaluate their test assertions.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    
                    // Detailed List of Results
                    if !results.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Execution Results")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            ForEach(results) { res in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        MethodBadgeView(method: res.request.method)
                                        Text(res.request.title)
                                            .font(.subheadline.bold())
                                            .lineLimit(1)
                                        Spacer()
                                        StatusBadgeView(statusCode: res.statusCode)
                                    }
                                    
                                    HStack(spacing: 12) {
                                        Label(String(format: "%.0f ms", res.durationMs), systemImage: "timer")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                        
                                        Label("\(res.sizeBytes) B", systemImage: "arrow.down.circle")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                        
                                        Spacer()
                                        
                                        if !res.assertionLogs.isEmpty {
                                            let passed = res.assertionLogs.filter { $0.isPassed }.count
                                            Text("Tests: \(passed)/\(res.assertionLogs.count)")
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(passed == res.assertionLogs.count ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                                .foregroundStyle(passed == res.assertionLogs.count ? Color.green : Color.red)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    
                                    // Individual assertion breakdowns
                                    if !res.assertionLogs.isEmpty {
                                        Divider()
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(res.assertionLogs) { a in
                                                HStack(spacing: 6) {
                                                    Image(systemName: a.isPassed ? "checkmark" : "xmark")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundStyle(a.isPassed ? .green : .red)
                                                    Text(a.description)
                                                        .font(.system(size: 11, design: .monospaced))
                                                        .foregroundStyle(.primary)
                                                    if let fail = a.failureReason {
                                                        Text("(\(fail))")
                                                            .font(.system(size: 10, design: .monospaced))
                                                            .foregroundStyle(.red)
                                                    }
                                                    Spacer()
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 10) {
                        if !isRunning {
                            Button {
                                Task {
                                    await runAll()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: hasFinished ? "arrow.clockwise" : "play.fill")
                                    Text(hasFinished ? "Run Again" : "Start Runner")
                                        .font(.subheadline.bold())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.top)
            }
            .navigationTitle("Collection Runner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                if !hasFinished && !isRunning {
                    await runAll()
                }
            }
        }
    }
    
    private func summaryCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func runAll() async {
        guard !collection.requests.isEmpty else { return }
        isRunning = true
        hasFinished = false
        results = []
        currentIndex = 0
        
        var envMap: [String: String] = [:]
        if let env = activeEnvironments.first {
            for v in env.variables {
                envMap[v.key] = v.value
            }
        }
        
        for (idx, req) in collection.requests.enumerated() {
            currentIndex = idx
            
            // Resolve URL, Headers, and Params
            let resolvedURL = VariableResolver.resolve(text: req.urlTemplate, using: envMap)
            var headers: [String: String] = [:]
            for p in req.keyValues where p.isEnabled && p.location == .header && !p.key.isEmpty {
                headers[p.key] = VariableResolver.resolve(text: p.value, using: envMap)
            }
            var queryItems: [URLQueryItem] = []
            for p in req.keyValues where p.isEnabled && p.location == .query && !p.key.isEmpty {
                let resolvedVal = VariableResolver.resolve(text: p.value, using: envMap)
                queryItems.append(URLQueryItem(name: p.key, value: resolvedVal))
            }
            let resolvedBody = VariableResolver.resolve(text: req.rawBodyContent ?? "", using: envMap)
            
            // Execute Network Call
            let netResp = await NativeNetworkClient.shared.execute(
                urlString: resolvedURL,
                method: req.method,
                headers: headers,
                queryItems: queryItems,
                body: resolvedBody,
                bodyType: req.bodyType
            )
            
            // Evaluate Assertions
            var assertionLogs: [AssertionEvaluationResult] = []
            for a in req.assertions where a.isEnabled {
                assertionLogs.append(AssertionEngine.evaluate(assertion: a, response: netResp))
            }
            
            let allPassed = assertionLogs.isEmpty ? true : assertionLogs.allSatisfy { $0.isPassed }
            
            // Save to execution history in SwiftData
            let execResult = SDExecutionResult(
                statusCode: netResp.statusCode,
                responseDurationMs: netResp.durationMs,
                responseBodySize: netResp.sizeBytes,
                responseBody: netResp.body,
                isAllAssertionsPassed: allPassed
            )
            execResult.request = req
            modelContext.insert(execResult)
            
            let res = RunnerItemResult(
                request: req,
                statusCode: netResp.statusCode,
                durationMs: netResp.durationMs,
                sizeBytes: netResp.sizeBytes,
                assertionLogs: assertionLogs,
                isAllPassed: allPassed,
                error: netResp.error
            )
            
            withAnimation(.snappy) {
                results.append(res)
            }
        }
        
        try? modelContext.save()
        isRunning = false
        hasFinished = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
