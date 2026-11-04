import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var collection: SDCollection
    
    @State private var showingAddRequestAlert = false
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
            
            Section("Saved Requests (\(collection.requests.count))") {
                if collection.requests.isEmpty {
                    ContentUnavailableView(
                        "No Requests",
                        systemImage: "paperplane",
                        description: Text("Save requests from the 'Requests' tab or add a new one with the + button.")
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
                    }
                    .onDelete(perform: deleteRequest)
                }
            }
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showingAddRequestAlert = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingAddRequestAlert) {
            newRequestSheet
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
                    TextField("Request Title", text: $newRequestTitle)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                    
                    Picker("Method", selection: $newRequestMethod) {
                        ForEach(HTTPMethodType.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    
                    TextField("URL", text: $newRequestURL, axis: .vertical)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle("New Request in Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddRequestAlert = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let req = SDRequest(
                            title: newRequestTitle.isEmpty ? newRequestURL : newRequestTitle,
                            urlTemplate: newRequestURL,
                            method: newRequestMethod,
                            bodyType: .none,
                            isHistoryItem: false
                        )
                        req.collection = collection
                        collection.requests.append(req)
                        modelContext.insert(req)
                        try? modelContext.save()
                        showingAddRequestAlert = false
                        newRequestTitle = ""
                        newRequestURL = "https://"
                    }
                    .disabled(newRequestURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
