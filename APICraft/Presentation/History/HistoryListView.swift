import SwiftUI
import SwiftData

public struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SDRequest> { $0.isHistoryItem }, sort: \SDRequest.createdAt, order: .reverse)
    private var historyRequests: [SDRequest]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                if historyRequests.isEmpty {
                    ContentUnavailableView(
                        "Історія порожня",
                        systemImage: "clock",
                        description: Text("Виконані запити автоматично з'являтимуться тут.")
                    )
                } else {
                    ForEach(historyRequests) { req in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(req.method.rawValue)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                
                                Text(req.urlTemplate)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                if let lastResult = req.executionHistory.last {
                                    StatusBadgeView(statusCode: lastResult.statusCode)
                                }
                            }
                            
                            Text(req.createdAt.formatted(date: .abbreviated, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteHistory)
                }
            }
            .navigationTitle("Історія")
        }
    }
    
    private func deleteHistory(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(historyRequests[index])
        }
    }
}
