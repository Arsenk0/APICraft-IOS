import SwiftUI
import SwiftData

public struct CollectionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDCollection.createdAt, order: .reverse) private var collections: [SDCollection]
    
    @State private var showingCreateAlert = false
    @State private var newCollectionName = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                if collections.isEmpty {
                    ContentUnavailableView(
                        "Колекції відсутні",
                        systemImage: "folder.badge.plus",
                        description: Text("Створіть свою першу колекцію запитів для тестування.")
                    )
                } else {
                    ForEach(collections) { collection in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(collection.name)
                                .font(.headline)
                            Text("\(collection.requests.count) запитів")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteCollections)
                }
            }
            .navigationTitle("Колекції")
            .toolbar {
                Button {
                    showingCreateAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .alert("Нова колекція", isPresented: $showingCreateAlert) {
                TextField("Назва", text: $newCollectionName)
                Button("Створити") {
                    if !newCollectionName.isEmpty {
                        let col = SDCollection(name: newCollectionName)
                        modelContext.insert(col)
                        newCollectionName = ""
                    }
                }
                Button("Скасувати", role: .cancel) {}
            }
        }
    }
    
    private func deleteCollections(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(collections[index])
        }
    }
}
