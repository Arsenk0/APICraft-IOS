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
                    }
                    .onDelete(perform: deleteRequest)
                }
            }
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                newRequestTitle = ""
                newRequestURL = "https://"
                newRequestMethod = .get
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
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        .lineLimit(1...3)
                }
                
                Section {
                    Button {
                        createRequest(andOpenInBuilder: true)
                    } label: {
                        HStack {
                            Spacer()
                            Label("Add & Open in Builder", systemImage: "arrow.up.right.square")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(newRequestURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("Opens this request directly in the Builder so you can configure headers, body, and query parameters immediately.")
                        .font(.caption2)
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
                        createRequest(andOpenInBuilder: false)
                    }
                    .disabled(newRequestURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func createRequest(andOpenInBuilder: Bool) {
        let trimmedTitle = newRequestTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = newRequestURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? trimmedURL : trimmedTitle
        
        let req = SDRequest(
            title: resolvedTitle,
            urlTemplate: trimmedURL,
            method: newRequestMethod,
            bodyType: .none,
            isHistoryItem: false
        )
        req.collection = collection
        collection.requests.append(req)
        modelContext.insert(req)
        try? modelContext.save()
        
        showingAddRequestAlert = false
        
        if andOpenInBuilder {
            AppNavigationState.shared.openInBuilder(request: req)
        }
        
        newRequestTitle = ""
        newRequestURL = "https://"
    }
}
