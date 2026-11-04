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
            Group {
                if collections.isEmpty {
                    ContentUnavailableView(
                        "No Collections",
                        systemImage: "folder.badge.plus",
                        description: Text("Tap the + button in the top right to create your first collection.")
                    )
                } else {
                    List {
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
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete(perform: deleteCollections)
                    }
                }
            }
            .navigationTitle("Collections")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newCollectionName = ""
                        showingCreateAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Collection", isPresented: $showingCreateAlert) {
                TextField("Collection Name (e.g. Auth API)", text: $newCollectionName)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                
                Button("Create") {
                    createCollection()
                }
                
                Button("Cancel", role: .cancel) {
                    newCollectionName = ""
                }
            } message: {
                Text("Enter a name for this collection.")
            }
        }
    }
    
    private func createCollection() {
        let trimmed = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let col = SDCollection(name: trimmed)
        modelContext.insert(col)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save new collection: \(error)")
        }
        newCollectionName = ""
    }
    
    private func deleteCollections(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(collections[index])
        }
        try? modelContext.save()
    }
}
