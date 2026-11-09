import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var collection: SDCollection
    
    @State private var showingAddRequestAlert = false
    @State private var showingRunnerSheet = false
    @State private var showingEditCollectionSheet = false
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteSingleRequest(request)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                AppNavigationState.shared.openInBuilder(request: request)
                            } label: {
                                Label("Open in Builder", systemImage: "arrow.up.right.square")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                deleteSingleRequest(request)
                            } label: {
                                Label("Delete Request", systemImage: "trash")
                            }
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
                Button {
                    showingEditCollectionSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
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
        .sheet(isPresented: $showingEditCollectionSheet) {
            EditCollectionSheet(collection: collection)
        }
    }
    
    private func deleteSingleRequest(_ req: SDRequest) {
        if let idx = collection.requests.firstIndex(where: { $0.id == req.id }) {
            collection.requests.remove(at: idx)
        }
        modelContext.delete(req)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    private func deleteRequest(offsets: IndexSet) {
        for index in offsets {
            if collection.requests.indices.contains(index) {
                let req = collection.requests[index]
                modelContext.delete(req)
            }
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
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Runner Header Card
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(collection.name)
                                .font(.headline)
                            Text("\(collection.requests.count) requests in run")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if isRunning {
                            ProgressView()
                                .padding(.trailing, 4)
                        } else if hasFinished {
                            let passedCount = results.filter { $0.isAllPassed }.count
                            HStack(spacing: 4) {
                                Image(systemName: passedCount == results.count ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                Text("\(passedCount)/\(results.count) Passed")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(passedCount == results.count ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                            .foregroundStyle(passedCount == results.count ? Color.green : Color.red)
                            .clipShape(Capsule())
                        }
                    }
                    
                    if isRunning {
                        ProgressView(value: Double(currentIndex), total: Double(collection.requests.count))
                            .progressViewStyle(.linear)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                // Result List
                List {
                    ForEach(results) { res in
                        Section {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    MethodBadgeView(method: res.request.method)
                                    Text(res.request.title)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    StatusBadgeView(statusCode: res.statusCode)
                                }
                                
                                HStack(spacing: 12) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "clock")
                                        Text("\(String(format: "%.0f", res.durationMs)) ms")
                                    }
                                    HStack(spacing: 3) {
                                        Image(systemName: "arrow.down.circle")
                                        Text(ByteCountFormatter.string(fromByteCount: Int64(res.sizeBytes), countStyle: .file))
                                    }
                                    HStack(spacing: 3) {
                                        Image(systemName: res.isAllPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(res.isAllPassed ? .green : .red)
                                        Text(res.isAllPassed ? "Assertions passed" : "Assertions failed")
                                            .foregroundStyle(res.isAllPassed ? .green : .red)
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                
                                if let err = res.error {
                                    Text("Error: \(err)")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                                
                                if !res.assertionLogs.isEmpty {
                                    Divider()
                                    VStack(alignment: .leading, spacing: 3) {
                                        ForEach(res.assertionLogs) { log in
                                            HStack(spacing: 6) {
                                                Image(systemName: log.isPassed ? "checkmark" : "xmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(log.isPassed ? .green : .red)
                                                Text(log.description)
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                
                // Bottom Button
                VStack {
                    if !isRunning {
                        Button {
                            Task {
                                await runCollection()
                            }
                        } label: {
                            HStack {
                                Image(systemName: hasFinished ? "arrow.clockwise" : "play.fill")
                                Text(hasFinished ? "Run Again" : "Start Run")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Runner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @MainActor
    private func runCollection() async {
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
        
        for req in collection.requests {
            currentIndex += 1
            let resolvedURL = VariableResolver.resolve(text: req.urlTemplate, using: envMap)
            var headers: [String: String] = [:]
            var queryItems: [URLQueryItem] = []
            
            for kv in req.keyValues where kv.isEnabled && !kv.key.isEmpty {
                let resolved = VariableResolver.resolve(text: kv.value, using: envMap)
                if kv.location == .header {
                    headers[kv.key] = resolved
                } else if kv.location == .query {
                    queryItems.append(URLQueryItem(name: kv.key, value: resolved))
                }
            }
            
            let body = req.rawBodyContent.map { VariableResolver.resolve(text: $0, using: envMap) }
            
            let resp = await NativeNetworkClient.shared.execute(
                urlString: resolvedURL,
                method: req.method,
                headers: headers,
                queryItems: queryItems,
                body: body,
                bodyType: req.bodyType
            )
            
            // Assertions
            var logs: [AssertionEvaluationResult] = []
            for a in req.assertions where a.isEnabled {
                let r = AssertionEngine.evaluate(assertion: a, response: resp)
                logs.append(r)
            }
            
            let allPassed = logs.isEmpty ? (resp.statusCode >= 200 && resp.statusCode < 400) : logs.allSatisfy { $0.isPassed }
            let item = RunnerItemResult(
                request: req,
                statusCode: resp.statusCode,
                durationMs: resp.durationMs,
                sizeBytes: resp.sizeBytes,
                assertionLogs: logs,
                isAllPassed: allPassed,
                error: resp.error
            )
            results.append(item)
            
            // Save execution history
            let exec = SDExecutionResult(
                statusCode: resp.statusCode,
                responseDurationMs: resp.durationMs,
                responseBodySize: resp.sizeBytes,
                responseBody: resp.body,
                isAllAssertionsPassed: allPassed
            )
            exec.request = req
            modelContext.insert(exec)
            for l in logs {
                let sLog = SDAssertionLog(
                    assertionDescription: l.description,
                    isPassed: l.isPassed,
                    failureReason: l.failureReason
                )
                exec.assertionLogs.append(sLog)
            }
        }
        
        try? modelContext.save()
        isRunning = false
        hasFinished = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
