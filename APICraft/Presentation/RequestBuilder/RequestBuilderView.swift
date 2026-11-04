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
            VStack(spacing: 8) {
                // Modern Top URL Card
                VStack(spacing: 10) {
                    if let activeEnv = activeEnvironments.first {
                        HStack(spacing: 6) {
                            Circle().fill(Color.green).frame(width: 7, height: 7)
                            Text("Середовище: \(activeEnv.name)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Menu {
                            ForEach(HTTPMethodType.allCases) { m in
                                Button {
                                    viewModel.method = m
                                } label: {
                                    HStack {
                                        Text(m.rawValue)
                                        if viewModel.method == m {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.method.rawValue)
                                    .font(.caption.bold().monospaced())
                                    .foregroundStyle(MethodBadgeView.color(for: viewModel.method))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(MethodBadgeView.color(for: viewModel.method).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        HStack {
                            TextField("URL (напр. {{base_url}}/api)", text: $viewModel.url)
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($isInputFocused)
                            
                            if !viewModel.url.isEmpty {
                                Button {
                                    viewModel.url = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Button {
                            isInputFocused = false
                            Task {
                                await viewModel.sendRequest(context: modelContext, activeEnv: activeEnvironments.first)
                            }
                        } label: {
                            Group {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.subheadline.bold())
                                }
                            }
                            .frame(width: 36, height: 36)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(viewModel.isLoading || viewModel.url.isEmpty)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                .padding(.top, 4)
                
                // Segments
                Picker("Вкладки", selection: $selectedTab) {
                    Text("Headers (\(viewModel.headers.count))").tag(0)
                    Text("Query (\(viewModel.queryParams.count))").tag(1)
                    Text("Body").tag(2)
                    Text("Відповідь").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 4)
                
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
                    VStack(alignment: .leading, spacing: 14) {
                        // Metrics Card
                        HStack(spacing: 12) {
                            StatusBadgeView(statusCode: resp.statusCode, showText: true)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.caption)
                                Text(String(format: "%.0f ms", resp.durationMs))
                                    .font(.caption.bold().monospacedDigit())
                            }
                            .foregroundStyle(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.caption)
                                Text("\(resp.sizeBytes) B")
                                    .font(.caption.bold().monospacedDigit())
                            }
                            .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Assertions
                        if !viewModel.assertionLogs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Результати перевірок (Assertions):")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                
                                ForEach(viewModel.assertionLogs) { log in
                                    HStack(spacing: 8) {
                                        Image(systemName: log.isPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(log.isPassed ? .green : .red)
                                        Text(log.description)
                                            .font(.caption)
                                        Spacer()
                                    }
                                    .padding(8)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Body Content with JSON Viewer
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Тіло відповіді:")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            
                            JSONSyntaxView(rawJSON: resp.body ?? "")
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                ContentUnavailableView(
                    "Немає відповіді",
                    systemImage: "paperplane.circle",
                    description: Text("Натисніть кнопку відправки вгорі, щоб надіслати запит та отримати результат.")
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
