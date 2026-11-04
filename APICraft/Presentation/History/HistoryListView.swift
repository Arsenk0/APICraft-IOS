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
    
    @State private var searchText = ""
    @State private var statusFilter: HistoryStatusFilter = .all
    @State private var selectedMethod: HTTPMethodType? = nil
    @State private var showingClearConfirmation = false
    
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
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Picker("Status", selection: $statusFilter) {
                                ForEach(HistoryStatusFilter.allCases) { f in
                                    Text(f.rawValue).tag(f)
                                }
                            }
                            .pickerStyle(.segmented)
                            
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
                                HStack(spacing: 4) {
                                    Text(selectedMethod?.rawValue ?? "Method")
                                        .font(.caption.bold())
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(selectedMethod != nil ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground))
                                .foregroundStyle(selectedMethod != nil ? Color.blue : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                    .background(Color(.systemBackground))
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
                            NavigationLink {
                                RequestDetailExecutionView(request: req)
                            } label: {
                                HStack(alignment: .center, spacing: 10) {
                                    MethodBadgeView(method: req.method)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(req.title)
                                            .font(.subheadline.bold())
                                            .lineLimit(1)
                                        
                                        Text(req.urlTemplate)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        
                                        HStack(spacing: 6) {
                                            Image(systemName: "clock")
                                                .font(.system(size: 9))
                                            Text(req.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                            
                                            if let lastResult = req.executionHistory.last {
                                                Text("•")
                                                    .font(.caption2)
                                                Text(String(format: "%.0f ms", lastResult.responseDurationMs))
                                                    .font(.caption2.monospacedDigit())
                                            }
                                        }
                                        .foregroundStyle(.tertiary)
                                    }
                                    
                                    Spacer(minLength: 4)
                                    
                                    if let lastResult = req.executionHistory.last {
                                        StatusBadgeView(statusCode: lastResult.statusCode)
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
        }
    }
    
    private func deleteHistory(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredRequests[index])
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
