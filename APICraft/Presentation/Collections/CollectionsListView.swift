import SwiftUI
import SwiftData

// MARK: - Collection Export / Import Codable Models
struct ExportedCollection: Codable {
    let name: String
    let details: String?
    let requests: [ExportedRequest]
    
    struct ExportedRequest: Codable {
        let title: String
        let url: String
        let method: String
        let bodyType: String
        let bodyContent: String?
        let headers: [ExportedKeyValue]
        let queryParams: [ExportedKeyValue]
        let assertions: [ExportedAssertion]
    }
    
    struct ExportedKeyValue: Codable {
        let key: String
        let value: String
        let isEnabled: Bool
    }
    
    struct ExportedAssertion: Codable {
        let target: String
        let comparison: String
        let expectedValue: String
        let isEnabled: Bool
        let keyPath: String?
    }
}

public struct CollectionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDCollection.createdAt, order: .reverse) private var collections: [SDCollection]
    
    @State private var showingCreateAlert = false
    @State private var newCollectionName = ""
    @State private var showingImportSheet = false
    @State private var importJSONText = ""
    @State private var importErrorMessage: String?
    @State private var showExportToast = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Group {
                if collections.isEmpty {
                    ContentUnavailableView(
                        "No Collections",
                        systemImage: "folder.badge.plus",
                        description: Text("Tap + in the top right to create or import your first collection.")
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
                            .swipeActions(edge: .leading) {
                                Button {
                                    let json = exportCollectionJSON(collection)
                                    UIPasteboard.general.string = json
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    withAnimation(.spring) {
                                        showExportToast = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation {
                                            showExportToast = false
                                        }
                                    }
                                } label: {
                                    Label("Copy JSON", systemImage: "square.and.arrow.up")
                                }
                                .tint(.indigo)
                            }
                        }
                        .onDelete(perform: deleteCollections)
                    }
                }
            }
            .navigationTitle("Collections")
            .overlay(alignment: .top) {
                if showExportToast {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Collection JSON copied to clipboard")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            newCollectionName = ""
                            showingCreateAlert = true
                        } label: {
                            Label("New Collection", systemImage: "plus")
                        }
                        
                        Button {
                            let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            importJSONText = clip.hasPrefix("{") ? clip : ""
                            importErrorMessage = nil
                            showingImportSheet = true
                        } label: {
                            Label("Import Collection (JSON)...", systemImage: "square.and.arrow.down")
                        }
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
            .sheet(isPresented: $showingImportSheet) {
                importSheet
            }
        }
    }
    
    private var importSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Paste exported collection JSON or Postman collection below:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                TextEditor(text: $importJSONText)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .frame(minHeight: 200)
                
                if let err = importErrorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
                
                Button {
                    if let clip = UIPasteboard.general.string {
                        importJSONText = clip
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Import Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingImportSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        if importCollection(from: importJSONText) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            showingImportSheet = false
                        } else {
                            importErrorMessage = "Invalid collection JSON format."
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        }
                    }
                    .disabled(importJSONText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.headline)
                }
            }
        }
    }
    
    private func createCollection() {
        let trimmed = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let col = SDCollection(name: trimmed)
        modelContext.insert(col)
        try? modelContext.save()
        newCollectionName = ""
    }
    
    private func deleteCollections(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(collections[index])
        }
        try? modelContext.save()
    }
    
    private func exportCollectionJSON(_ collection: SDCollection) -> String {
        let reqs = collection.requests.map { req in
            ExportedCollection.ExportedRequest(
                title: req.title,
                url: req.urlTemplate,
                method: req.method.rawValue,
                bodyType: req.bodyType.rawValue,
                bodyContent: req.rawBodyContent,
                headers: req.keyValues.filter { $0.location == .header }.map {
                    ExportedCollection.ExportedKeyValue(key: $0.key, value: $0.value, isEnabled: $0.isEnabled)
                },
                queryParams: req.keyValues.filter { $0.location == .query }.map {
                    ExportedCollection.ExportedKeyValue(key: $0.key, value: $0.value, isEnabled: $0.isEnabled)
                },
                assertions: req.assertions.map {
                    ExportedCollection.ExportedAssertion(
                        target: $0.target.rawValue,
                        comparison: $0.comparison.rawValue,
                        expectedValue: $0.expectedValue,
                        isEnabled: $0.isEnabled,
                        keyPath: $0.keyPath
                    )
                }
            )
        }
        
        let exported = ExportedCollection(name: collection.name, details: collection.details, requests: reqs)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(exported), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
    
    private func importCollection(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        
        let decoder = JSONDecoder()
        if let exp = try? decoder.decode(ExportedCollection.self, from: data) {
            let col = SDCollection(name: exp.name, details: exp.details)
            modelContext.insert(col)
            
            for r in exp.requests {
                let method = HTTPMethodType(rawValue: r.method) ?? .get
                let bodyType = BodyType(rawValue: r.bodyType) ?? .none
                let req = SDRequest(
                    title: r.title,
                    urlTemplate: r.url,
                    method: method,
                    bodyType: bodyType,
                    rawBodyContent: r.bodyContent,
                    isHistoryItem: false
                )
                req.collection = col
                modelContext.insert(req)
                
                for h in r.headers {
                    let param = SDRequestParameter(key: h.key, value: h.value, isEnabled: h.isEnabled, location: .header)
                    req.keyValues.append(param)
                }
                for q in r.queryParams {
                    let param = SDRequestParameter(key: q.key, value: q.value, isEnabled: q.isEnabled, location: .query)
                    req.keyValues.append(param)
                }
                for a in r.assertions {
                    let target = AssertionTarget(rawValue: a.target) ?? .statusCode
                    let comp = AssertionComparison(rawValue: a.comparison) ?? .equals
                    let assertion = SDTestAssertion(
                        target: target,
                        keyPath: a.keyPath,
                        comparison: comp,
                        expectedValue: a.expectedValue,
                        isEnabled: a.isEnabled
                    )
                    req.assertions.append(assertion)
                }
                col.requests.append(req)
            }
            
            try? modelContext.save()
            return true
        }
        
        return false
    }
}
