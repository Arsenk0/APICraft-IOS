import SwiftUI
import SwiftData

enum HistoryStatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case success = "2xx Success"
    case errors = "Errors (4xx/5xx)"
    
    var id: String { rawValue }
}

public struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SDRequest> { $0.isHistoryItem }, sort: \SDRequest.createdAt, order: .reverse)
    private var historyRequests: [SDRequest]
    @Query(sort: \SDCollection.createdAt, order: .reverse)
    private var collections: [SDCollection]
    
    @State private var searchText = ""
    @State private var statusFilter: HistoryStatusFilter = .all
    @State private var selectedMethod: HTTPMethodType? = nil
    @State private var showingClearConfirmation = false
    
    // Save to Collection
    @State private var showingSaveSheet = false
    @State private var requestToSave: SDRequest?
    @State private var saveTitle = ""
    @State private var selectedCollectionForSave: SDCollection?
    @State private var showingNewColAlert = false
    @State private var newColName = ""
    
    public init() {}
    
    private var filteredRequests: [SDRequest] {
        historyRequests.filter { req in
            // Search text
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !query.isEmpty {
                let matchesTitle = req.title.lowercased().contains(query)
                let matchesURL = req.urlTemplate.lowercased().contains(query)
                if !matchesTitle && !matchesURL {
                    return false
                }
            }
            
            // Method filter
            if let method = selectedMethod, req.method != method {
                return false
            }
            
            // Status code filter
            if let lastCode = req.executionHistory.last?.statusCode {
                switch statusFilter {
                case .all:
                    break
                case .success:
                    if lastCode < 200 || lastCode >= 300 { return false }
                case .errors:
                    if lastCode < 400 { return false }
                }
            } else if statusFilter != .all {
                return false
            }
            
            return true
        }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Bar
                if !historyRequests.isEmpty {
                    VStack(spacing: 10) {
                        // Full-width status filter segment
                        Picker("Status Filter", selection: $statusFilter) {
                            ForEach(HistoryStatusFilter.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        // Secondary bar: Method dropdown capsule, entry counter, and reset button
                        HStack(spacing: 8) {
                            Menu {
                                Button("All Methods") {
                                    selectedMethod = nil
                                }
                                Divider()
                                ForEach(HTTPMethodType.allCases) { m in
                                    Button(m.rawValue) {
                                        selectedMethod = m
                                    }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(selectedMethod?.rawValue ?? "All Methods")
                                        .font(.caption.bold())
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedMethod != nil ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground))
                                .foregroundStyle(selectedMethod != nil ? Color.blue : Color.primary)
                                .clipShape(Capsule())
                            }
                            
                            Spacer()
                            
                            Text("Showing \(filteredRequests.count) \(filteredRequests.count == 1 ? "entry" : "entries")")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            if statusFilter != .all || selectedMethod != nil || !searchText.isEmpty {
                                Button {
                                    withAnimation {
                                        statusFilter = .all
                                        selectedMethod = nil
                                        searchText = ""
                                    }
                                } label: {
                                    Text("Reset")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .background(Color(.systemGroupedBackground))
                }
                
                List {
                    if historyRequests.isEmpty {
                        ContentUnavailableView(
                            "History is Empty",
                            systemImage: "clock.arrow.circlepath",
                            description: Text("Every executed request will automatically be saved here with execution details and status.")
                        )
                    } else if filteredRequests.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ForEach(filteredRequests) { req in
                            let lastResult = req.executionHistory.last
                            NavigationLink {
                                RequestDetailExecutionView(request: req)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    // Header: Method + Title + Status
                                    HStack(alignment: .center, spacing: 8) {
                                        MethodBadgeView(method: req.method)
                                        
                                        Text(req.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        
                                        Spacer(minLength: 4)
                                        
                                        if let lastResult {
                                            StatusBadgeView(statusCode: lastResult.statusCode)
                                        }
                                    }
                                    
                                    // URL
                                    Text(req.urlTemplate)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    
                                    // Footer Metrics & Badges
                                    HStack(spacing: 8) {
                                        // Timestamp
                                        HStack(spacing: 3) {
                                            Image(systemName: "clock")
                                                .font(.system(size: 9))
                                            Text(req.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                        }
                                        .foregroundStyle(.secondary)
                                        
                                        if let lastResult {
                                            // Latency Pill
                                            HStack(spacing: 2) {
                                                Image(systemName: "bolt.fill")
                                                    .font(.system(size: 8))
                                                Text(String(format: "%.0f ms", lastResult.responseDurationMs))
                                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            }
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(
                                                lastResult.responseDurationMs < 400 ? Color.green.opacity(0.12) :
                                                (lastResult.responseDurationMs < 1200 ? Color.orange.opacity(0.12) : Color.red.opacity(0.12))
                                            )
                                            .foregroundStyle(
                                                lastResult.responseDurationMs < 400 ? Color.green :
                                                (lastResult.responseDurationMs < 1200 ? Color.orange : Color.red)
                                            )
                                            .clipShape(Capsule())
                                            
                                            // Size Pill
                                            if lastResult.responseBodySize > 0 {
                                                Text(ByteCountFormatter.string(fromByteCount: Int64(lastResult.responseBodySize), countStyle: .file))
                                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color(.tertiarySystemBackground))
                                                    .foregroundStyle(.secondary)
                                                    .clipShape(Capsule())
                                            }
                                            
                                            // Test Assertions Indicator
                                            if !lastResult.assertionLogs.isEmpty {
                                                let passedCount = lastResult.assertionLogs.filter { $0.isPassed }.count
                                                let totalCount = lastResult.assertionLogs.count
                                                HStack(spacing: 2) {
                                                    Image(systemName: lastResult.isAllAssertionsPassed ? "checkmark.shield.fill" : "xmark.shield.fill")
                                                        .font(.system(size: 8))
                                                    Text("\(passedCount)/\(totalCount) tests")
                                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                                }
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(lastResult.isAllAssertionsPassed ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                                                .foregroundStyle(lastResult.isAllAssertionsPassed ? Color.green : Color.red)
                                                .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    AppNavigationState.shared.openInBuilder(request: req)
                                } label: {
                                    Label("Open in Builder", systemImage: "arrow.up.right.square")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteRequest(req)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    requestToSave = req
                                    saveTitle = req.title
                                    selectedCollectionForSave = collections.first
                                    showingSaveSheet = true
                                } label: {
                                    Label("Save to Collection", systemImage: "folder.badge.plus")
                                }
                                .tint(.orange)
                            }
                            .contextMenu {
                                Button {
                                    AppNavigationState.shared.openInBuilder(request: req)
                                } label: {
                                    Label("Open in Builder", systemImage: "arrow.up.right.square")
                                }
                                
                                Button {
                                    requestToSave = req
                                    saveTitle = req.title
                                    selectedCollectionForSave = collections.first
                                    showingSaveSheet = true
                                } label: {
                                    Label("Save to Collection", systemImage: "folder.badge.plus")
                                }
                                
                                Button {
                                    UIPasteboard.general.string = req.urlTemplate
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } label: {
                                    Label("Copy URL", systemImage: "link")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    deleteRequest(req)
                                } label: {
                                    Label("Delete Log", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteHistory)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by title or URL...")
            .navigationTitle("History")
            .toolbar {
                if !historyRequests.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                    }
                }
            }
            .alert("Clear All History?", isPresented: $showingClearConfirmation) {
                Button("Clear History", role: .destructive) {
                    clearAllHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All saved request history logs will be permanently deleted.")
            }
            .sheet(isPresented: $showingSaveSheet) {
                saveToCollectionSheet
            }
        }
    }
    
    private var saveToCollectionSheet: some View {
        NavigationStack {
            Form {
                Section("Request Title") {
                    TextField("Title", text: $saveTitle)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingSaveSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let targetCol = selectedCollectionForSave ?? collections.first
                        if let req = requestToSave, let col = targetCol {
                            saveToCollection(req: req, col: col, title: saveTitle)
                        }
                        showingSaveSheet = false
                    }
                    .disabled(saveTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (selectedCollectionForSave == nil && collections.isEmpty))
                }
            }
            .alert("New Collection", isPresented: $showingNewColAlert) {
                TextField("Collection Name", text: $newColName)
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
    
    private func saveToCollection(req: SDRequest, col: SDCollection, title: String) {
        let newReq = SDRequest(
            title: title.isEmpty ? req.title : title,
            urlTemplate: req.urlTemplate,
            method: req.method,
            bodyType: req.bodyType,
            rawBodyContent: req.rawBodyContent,
            isHistoryItem: false
        )
        newReq.collection = col
        for kv in req.keyValues {
            let p = SDRequestParameter(key: kv.key, value: kv.value, isEnabled: kv.isEnabled, location: kv.location)
            newReq.keyValues.append(p)
        }
        for a in req.assertions {
            let p = SDTestAssertion(target: a.target, keyPath: a.keyPath, comparison: a.comparison, expectedValue: a.expectedValue, isEnabled: a.isEnabled)
            newReq.assertions.append(p)
        }
        modelContext.insert(newReq)
        col.requests.append(newReq)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    private func deleteRequest(_ request: SDRequest) {
        modelContext.delete(request)
        try? modelContext.save()
    }
    
    private func deleteHistory(offsets: IndexSet) {
        for index in offsets {
            if filteredRequests.indices.contains(index) {
                modelContext.delete(filteredRequests[index])
            }
        }
        try? modelContext.save()
    }
    
    private func clearAllHistory() {
        for item in historyRequests {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}
