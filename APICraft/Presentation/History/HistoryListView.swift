import SwiftUI
import SwiftData

public struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SDRequest> { $0.isHistoryItem }, sort: \SDRequest.createdAt, order: .reverse)
    private var historyRequests: [SDRequest]
    
    @State private var showingClearConfirmation = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                if historyRequests.isEmpty {
                    ContentUnavailableView(
                        "History is Empty",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Every executed request will automatically be saved here with execution details and status.")
                    )
                } else {
                    ForEach(historyRequests) { req in
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
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 9))
                                        Text(req.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
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
                    }
                    .onDelete(perform: deleteHistory)
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !historyRequests.isEmpty {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                }
            }
            .confirmationDialog(
                "Clear All History?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
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
            modelContext.delete(historyRequests[index])
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
