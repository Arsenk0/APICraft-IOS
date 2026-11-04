import SwiftUI
import SwiftData

public struct RequestBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SDEnvironment> { $0.isSelected }) private var activeEnvironments: [SDEnvironment]
    @Query(sort: \SDCollection.name) private var collections: [SDCollection]
    
    @State private var viewModel = RequestBuilderViewModel()
    @State private var selectedTab = 0 // 0: Headers, 1: Query, 2: Body, 3: Response
    @FocusState private var isInputFocused: Bool
    
    @State private var showingSaveSheet = false
    @State private var requestSaveTitle = ""
    @State private var selectedCollectionForSave: SDCollection?
    @State private var showingNewColAlert = false
    @State private var newColName = ""
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top URL Bar
                VStack(spacing: 8) {
                    HStack {
                        Picker("Метод", selection: $viewModel.method) {
                            ForEach(HTTPMethodType.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        TextField("Введіть URL (напр. {{base_url}}/api)", text: $viewModel.url)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($isInputFocused)
                        
                        Button {
                            isInputFocused = false
                            Task {
                                await viewModel.sendRequest(context: modelContext, activeEnv: activeEnvironments.first)
                            }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                                    .padding(.horizontal, 6)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isLoading || viewModel.url.isEmpty)
                    }
                    
                    if let activeEnv = activeEnvironments.first {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Активне середовище: \(activeEnv.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Segments
                Picker("Вкладки", selection: $selectedTab) {
                    Text("Headers (\(viewModel.headers.count))").tag(0)
                    Text("Query (\(viewModel.queryParams.count))").tag(1)
                    Text("Body").tag(2)
                    Text("Відповідь").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                Divider()
                
                // Tab Content
                Group {
                    switch selectedTab {
                    case 0:
                        headersTab
                    case 1:
                        queryTab
                    case 2:
                        bodyTab
                    default:
                        responseTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("APICraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isInputFocused = false
                        requestSaveTitle = viewModel.title.isEmpty ? viewModel.url : viewModel.title
                        selectedCollectionForSave = collections.first
                        showingSaveSheet = true
                    } label: {
                        Label("Зберегти", systemImage: "folder.badge.plus")
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        isInputFocused = false
                    }
                    .font(.body.bold())
                }
            }
            .sheet(isPresented: $showingSaveSheet) {
                saveToCollectionSheet
            }
        }
    }
    
    private var headersTab: some View {
        List {
            ForEach($viewModel.headers) { $item in
                HStack {
                    Toggle("", isOn: $item.isEnabled)
                        .labelsHidden()
                    TextField("Key", text: $item.key)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                    TextField("Value", text: $item.value)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                }
            }
            .onDelete { indices in
                viewModel.headers.remove(atOffsets: indices)
            }
            
            Button {
                viewModel.headers.append(RequestKeyValue(key: "", value: "", isEnabled: true))
            } label: {
                Label("Додати заголовок", systemImage: "plus")
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    private var queryTab: some View {
        List {
            ForEach($viewModel.queryParams) { $item in
                HStack {
                    Toggle("", isOn: $item.isEnabled)
                        .labelsHidden()
                    TextField("Параметр", text: $item.key)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                    TextField("Значення", text: $item.value)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                }
            }
            .onDelete { indices in
                viewModel.queryParams.remove(atOffsets: indices)
            }
            
            Button {
                viewModel.queryParams.append(RequestKeyValue(key: "", value: "", isEnabled: true))
            } label: {
                Label("Додати параметр", systemImage: "plus")
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    private var bodyTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Тип тіла", selection: $viewModel.bodyType) {
                ForEach(BodyType.allCases) { b in
                    Text(b.rawValue).tag(b)
                }
            }
            .pickerStyle(.menu)
            
            TextEditor(text: $viewModel.bodyText)
                .font(.system(.body, design: .monospaced))
                .focused($isInputFocused)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
    }
    
    private var responseTab: some View {
        Group {
            if let resp = viewModel.response {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Metrics Card
                        HStack(spacing: 16) {
                            StatusBadgeView(statusCode: resp.statusCode)
                            
                            Label(String(format: "%.0f ms", resp.durationMs), systemImage: "timer")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            
                            Label("\(resp.sizeBytes) B", systemImage: "doc")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        // Assertions
                        if !viewModel.assertionLogs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Перевірки (Assertions):")
                                    .font(.subheadline.bold())
                                
                                ForEach(viewModel.assertionLogs) { log in
                                    HStack {
                                        Image(systemName: log.isPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(log.isPassed ? .green : .red)
                                        Text(log.description)
                                            .font(.caption)
                                        Spacer()
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        // Body Content
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Тіло відповіді:")
                                .font(.subheadline.bold())
                            
                            Text(resp.body ?? "(порожньо)")
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                ContentUnavailableView(
                    "Немає відповіді",
                    systemImage: "network",
                    description: Text("Натисніть кнопку відправки для надсилання запиту.")
                )
            }
        }
    }
    
    private var saveToCollectionSheet: some View {
        NavigationStack {
            Form {
                Section("Назва запиту") {
                    TextField("Наприклад: Отримати користувача", text: $requestSaveTitle)
                        .focused($isInputFocused)
                }
                
                Section("Колекція") {
                    if collections.isEmpty {
                        Text("У вас ще немає створених колекцій.")
                            .foregroundStyle(.secondary)
                        Button("Створити нову колекцію") {
                            showingNewColAlert = true
                        }
                    } else {
                        Picker("Оберіть колекцію", selection: $selectedCollectionForSave) {
                            ForEach(collections) { col in
                                Text(col.name).tag(Optional(col))
                            }
                        }
                        
                        Button {
                            showingNewColAlert = true
                        } label: {
                            Label("Створити ще одну колекцію", systemImage: "plus")
                        }
                    }
                }
            }
            .navigationTitle("Зберегти запит")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") {
                        showingSaveSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        if let targetCol = selectedCollectionForSave ?? collections.first {
                            viewModel.saveToCollection(
                                collection: targetCol,
                                customTitle: requestSaveTitle,
                                context: modelContext
                            )
                            showingSaveSheet = false
                        }
                    }
                    .disabled(collections.isEmpty && selectedCollectionForSave == nil)
                }
            }
            .alert("Нова колекція", isPresented: $showingNewColAlert) {
                TextField("Назва колекції", text: $newColName)
                Button("Створити") {
                    if !newColName.isEmpty {
                        let newCol = SDCollection(name: newColName)
                        modelContext.insert(newCol)
                        selectedCollectionForSave = newCol
                        newColName = ""
                    }
                }
                Button("Скасувати", role: .cancel) {}
            }
        }
        .presentationDetents([.medium])
    }
}
