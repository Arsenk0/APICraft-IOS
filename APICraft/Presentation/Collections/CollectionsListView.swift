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
                        "No Collections",
                        systemImage: "folder.badge.plus",
                        description: Text("Create your first collection to organize and test API requests.")
                    )
                } else {
                    ForEach(collections) { collection in
                        NavigationLink {
                            CollectionDetailView(collection: collection)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                Text("\(collection.requests.count) \(collection.requests.count == 1 ? "request" : "requests")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .onDelete(perform: deleteCollections)
                }
            }
            .navigationTitle("Collections")
            .toolbar {
                Button {
                    showingCreateAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .alert("New Collection", isPresented: $showingCreateAlert) {
                TextField("Collection Name", text: $newCollectionName)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                Button("Create") {
                    if !newCollectionName.isEmpty {
                        let col = SDCollection(name: newCollectionName)
                        modelContext.insert(col)
                        newCollectionName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newCollectionName = ""
                }
            }
        }
    }
    
    private func deleteCollections(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(collections[index])
        }
    }
}
