import SwiftUI
import SwiftData

struct RequestDetailExecutionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<SDEnvironment> { $0.isSelected }) private var activeEnvironments: [SDEnvironment]
    @Query(sort: \SDCollection.createdAt, order: .reverse) private var collections: [SDCollection]
    
    @Bindable var request: SDRequest
    @State private var isExecuting = false
    @State private var lastResponse: NetworkResponse?
    @FocusState private var isFocused: Bool
    
    @State private var showingDeleteAlert = false
    @State private var latestAssertionLogs: [AssertionEvaluationResult] = []
    
    // Unsaved Changes Tracking
    @State private var initialTitle: String = ""
    @State private var initialURL: String = ""
    @State private var initialMethod: HTTPMethodType = .get
    @State private var showingUnsavedAlert = false
    
    // Save from history to collection state
    @State private var showingSaveSheet = false
    @State private var saveTitle = ""
    @State private var selectedCollectionForSave: SDCollection?
    @State private var showingNewColAlert = false
    @State private var newColName = ""
    
    init(request: SDRequest) {
        self.request = request
    }
    
    private var hasUnsavedChanges: Bool {
        guard !request.isHistoryItem else { return false }
        return request.title != initialTitle ||
               request.urlTemplate != initialURL ||
               request.method != initialMethod
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
                if request.isHistoryItem {
                    // History items are strictly read-only
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            MethodBadgeView(method: request.method)
                            Text(request.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("Read-Only Log")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                        
                        Text(request.urlTemplate)
                            .font(.system(size: 13.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .padding(.vertical, 2)
                    }
                } else {
                    // Editable Request from Collection
                    HStack(alignment: .top, spacing: 10) {
                        Picker("Method", selection: $request.method) {
                            ForEach(HTTPMethodType.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .padding(.top, 2)
                        
                        DeselectableURLField(text: $request.urlTemplate, placeholder: "https://api.example.com")
                            .frame(minHeight: 34)
                    }
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
                                Image(systemName: "play.fill")
                                Text("Execute Request")
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text("Re-execute")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isExecuting || request.urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    // Show "Save to Collection" button when viewing a history execution
                    if request.isHistoryItem {
                        Button {
                            isFocused = false
                            saveTitle = request.title.replacingOccurrences(of: "[Test] ", with: "")
                            selectedCollectionForSave = collections.first
                            showingSaveSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.plus")
                                Text("Save to Collection...")
                            }
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .tint(.indigo)
                    }
                }
            }
            
            if !queryParams.isEmpty {
                Section("Query Parameters (\(queryParams.count))") {
                    ForEach(queryParams) { param in
                        HStack {
                            Text(param.key)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                            Spacer()
                            Text(param.value)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            if !headers.isEmpty {
                Section("Headers (\(headers.count))") {
                    ForEach(headers) { header in
                        HStack {
                            Text(header.key)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                            Spacer()
                            Text(header.value)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            if request.bodyType != .none, let body = request.rawBodyContent, !body.isEmpty {
                Section("Body (\(request.bodyType.rawValue))") {
                    Text(body)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            
            // Latest Execution Response Section
            if let resp = lastResponse {
                Section("Response") {
                    HStack(spacing: 8) {
                        StatusBadgeView(statusCode: resp.statusCode)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(Int(resp.durationMs.rounded())) ms")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                                .font(.caption2)
                            Text("\(resp.sizeBytes) B")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    
                    if !latestAssertionLogs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Assertions (\(latestAssertionLogs.filter { $0.isPassed }.count)/\(latestAssertionLogs.count) Passed)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            
                            ForEach(Array(latestAssertionLogs.enumerated()), id: \.offset) { _, log in
                                HStack(spacing: 6) {
                                    Image(systemName: log.isPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(log.isPassed ? .green : .red)
                                        .font(.caption)
                                    Text(log.description)
                                        .font(.caption)
                                    if let fail = log.failureReason {
                                        Text("— \(fail)")
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if !resp.headers.isEmpty {
                        DisclosureGroup("Response Headers (\(resp.headers.count))") {
                            ForEach(Array(resp.headers.keys.sorted()), id: \.self) { key in
                                HStack(alignment: .top) {
                                    Text(key)
                                        .font(.caption.bold())
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(resp.headers[key] ?? "")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    
                    if let body = resp.body, !body.isEmpty {
                        JSONSyntaxView(rawJSON: body)
                            .padding(.top, 4)
                    }
                }
            } else if let lastExec = request.executionHistory.last {
                Section("Last Recorded Execution") {
                    HStack(spacing: 8) {
                        StatusBadgeView(statusCode: lastExec.statusCode)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(Int(lastExec.responseDurationMs.rounded())) ms")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                                .font(.caption2)
                            Text("\(lastExec.responseBodySize) B")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(lastExec.executedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                    
                    if !lastExec.assertionLogs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            let passedCount = lastExec.assertionLogs.filter { $0.isPassed }.count
                            Text("Assertions (\(passedCount)/\(lastExec.assertionLogs.count) Passed)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            
                            ForEach(lastExec.assertionLogs) { log in
                                HStack(spacing: 6) {
                                    Image(systemName: log.isPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(log.isPassed ? .green : .red)
                                        .font(.caption)
                                    Text(log.assertionDescription)
                                        .font(.caption)
                                    if let fail = log.failureReason {
                                        Text("— \(fail)")
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if let headers = lastExec.responseHeaders, !headers.isEmpty {
                        DisclosureGroup("Response Headers (\(headers.count))") {
                            ForEach(Array(headers.keys.sorted()), id: \.self) { key in
                                HStack(alignment: .top) {
                                    Text(key)
                                        .font(.caption.bold())
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(headers[key] ?? "")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    
                    if let body = lastExec.responseBody, !body.isEmpty {
                        JSONSyntaxView(rawJSON: body)
                            .padding(.top, 4)
                    }
                }
            }
            
            if !request.executionHistory.isEmpty {
                Section("Execution History (\(request.executionHistory.count))") {
                    ForEach(request.executionHistory.reversed()) { hist in
                        HStack(spacing: 8) {
                            StatusBadgeView(statusCode: hist.statusCode)
                            Text("\(Int(hist.responseDurationMs.rounded())) ms")
                                .font(.caption)
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
        .navigationBarBackButtonHidden(!request.isHistoryItem && hasUnsavedChanges)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            initialTitle = request.title
            initialURL = request.urlTemplate
            initialMethod = request.method
        }
        .toolbar {
            if !request.isHistoryItem && hasUnsavedChanges {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingUnsavedAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .alert("Unsaved Changes", isPresented: $showingUnsavedAlert) {
            Button("Save Changes") {
                try? modelContext.save()
                dismiss()
            }
            Button("Discard Changes", role: .destructive) {
                request.title = initialTitle
                request.urlTemplate = initialURL
                request.method = initialMethod
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved modifications to '\(request.title)'. Do you want to save them?")
        }
        .alert("Delete Request", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteThisRequest()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(request.title)'?")
        }
        .sheet(isPresented: $showingSaveSheet) {
            saveToCollectionSheet
        }
    }
    
    private var saveToCollectionSheet: some View {
        NavigationStack {
            Form {
                Section("Request Title") {
                    TextField("Title", text: $saveTitle)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                }
                
                Section("Target Collection") {
                    if collections.isEmpty {
                        Text("No collections available. Create one below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Collection", selection: $selectedCollectionForSave) {
                            ForEach(collections) { col in
                                Text(col.name).tag(col as SDCollection?)
                            }
                        }
                    }
                    
                    Button {
                        showingNewColAlert = true
                    } label: {
                        Label("New Collection", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Save to Collection")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingSaveSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let targetCol = selectedCollectionForSave ?? collections.first
                        if let col = targetCol {
                            saveToCollection(col: col, title: saveTitle)
                        }
                        showingSaveSheet = false
                    }
                    .disabled(saveTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (selectedCollectionForSave == nil && collections.isEmpty))
                }
            }
            .alert("New Collection", isPresented: $showingNewColAlert) {
                TextField("Collection Name", text: $newColName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                Button("Create") {
                    let col = SDCollection(name: newColName)
                    modelContext.insert(col)
                    try? modelContext.save()
                    selectedCollectionForSave = col
                    newColName = ""
                }
                Button("Cancel", role: .cancel) {
                    newColName = ""
                }
            }
        }
    }
    
    private func deleteThisRequest() {
        if let col = request.collection, let idx = col.requests.firstIndex(where: { $0.id == request.id }) {
            col.requests.remove(at: idx)
        }
        modelContext.delete(request)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
    
    private func saveToCollection(col: SDCollection, title: String) {
        let newReq = SDRequest(
            title: title.isEmpty ? request.title : title,
            urlTemplate: request.urlTemplate,
            method: request.method,
            bodyType: request.bodyType,
            rawBodyContent: request.rawBodyContent,
            isHistoryItem: false
        )
        newReq.collection = col
        for kv in request.keyValues {
            let p = SDRequestParameter(key: kv.key, value: kv.value, isEnabled: kv.isEnabled, location: kv.location)
            newReq.keyValues.append(p)
        }
        for a in request.assertions {
            let p = SDTestAssertion(target: a.target, keyPath: a.keyPath, comparison: a.comparison, expectedValue: a.expectedValue, isEnabled: a.isEnabled)
            newReq.assertions.append(p)
        }
        modelContext.insert(newReq)
        if !col.requests.contains(where: { $0.id == newReq.id }) {
            col.requests.append(newReq)
        }
        col.updatedAt = Date()
        do {
            try modelContext.save()
            print("✅ [APICraft] Saved copy to collection '\(col.name)'")
        } catch {
            print("❌ [APICraft] Failed to save copy to collection: \(error)")
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    @MainActor
    private func executeRequest() async {
        isExecuting = true
        defer { isExecuting = false }
        
        let result = await RequestExecutionService.execute(
            request: request,
            activeEnvironment: activeEnvironments.first,
            context: modelContext,
            recordHistoryCopy: true
        )
        
        self.lastResponse = result.response
        self.latestAssertionLogs = result.logs
        UINotificationFeedbackGenerator().notificationOccurred(result.allPassed ? .success : .error)
    }
}
