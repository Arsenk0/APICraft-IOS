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
                    if let details = collection.details, !details.isEmpty {
                        Text(details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Створено: \(collection.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            
            Section("Збережені запити (\(collection.requests.count))") {
                if collection.requests.isEmpty {
                    ContentUnavailableView(
                        "Запитів немає",
                        systemImage: "paperplane",
                        description: Text("Збережіть запит сюди з вкладки 'Запити' або додайте новий через кнопку +.")
                    )
                } else {
                    ForEach(collection.requests) { request in
                        NavigationLink {
                            RequestDetailExecutionView(request: request)
                        } label: {
                            HStack(spacing: 12) {
                                Text(request.method.rawValue)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(methodColor(request.method).opacity(0.15))
                                    .foregroundStyle(methodColor(request.method))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(request.title)
                                        .font(.subheadline.bold())
                                        .lineLimit(1)
                                    Text(request.urlTemplate)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
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
    
    private func methodColor(_ method: HTTPMethodType) -> Color {
        switch method {
        case .get: return .blue
        case .post: return .green
        case .put: return .orange
        case .delete: return .red
        case .patch: return .purple
        default: return .gray
        }
    }
    
    private var newRequestSheet: some View {
        NavigationStack {
            Form {
                Section("Інформація про запит") {
                    TextField("Назва запиту", text: $newRequestTitle)
                    
                    Picker("Метод", selection: $newRequestMethod) {
                        ForEach(HTTPMethodType.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    
                    TextField("URL", text: $newRequestURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Новий запит у колекцію")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") {
                        showingAddRequestAlert = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Додати") {
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
                    .disabled(newRequestURL.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
