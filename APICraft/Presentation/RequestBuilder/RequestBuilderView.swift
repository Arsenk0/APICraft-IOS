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
            VStack(spacing: 10) {
                // 1. Environment Indicator
                if let activeEnv = activeEnvironments.first {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 7, height: 7)
                        Text("Середовище: \(activeEnv.name)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
                
                // 2. Horizontal Method Bar with Vibrant Full-Fill Colors
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(HTTPMethodType.allCases) { m in
                            let isSelected = viewModel.method == m
                            let color = MethodBadgeView.color(for: m)
                            
                            Button {
                                withAnimation(.snappy(duration: 0.2)) {
                                    viewModel.method = m
                                }
                            } label: {
                                Text(m.rawValue)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? color : color.opacity(0.12))
                                    .foregroundStyle(isSelected ? Color.white : color)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // 3. Spacious Full-Width URL Input Box
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TextField("https://api.example.com/v1/resource", text: $viewModel.url)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isInputFocused)
                    
                    if !viewModel.url.isEmpty {
                        Button {
                            viewModel.url = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    } else if UIPasteboard.general.hasStrings {
                        Button {
                            if let pasteString = UIPasteboard.general.string {
                                viewModel.url = pasteString
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                
                // 4. Prominent Full-Width Send Request Button
                Button {
                    isInputFocused = false
                    Task {
                        await viewModel.sendRequest(context: modelContext, activeEnv: activeEnvironments.first)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = 3 // Auto-switch to "Відповідь"
                        }
                        let haptic = UINotificationFeedbackGenerator()
                        if let code = viewModel.response?.statusCode, code >= 200 && code < 400 {
                            haptic.notificationOccurred(.success)
                        } else {
                            haptic.notificationOccurred(.warning)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                            Text("Надсилання запиту...")
                                .font(.subheadline.bold())
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.subheadline.bold())
                            Text("Надіслати запит")
                                .font(.subheadline.bold())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(viewModel.url.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.isLoading || viewModel.url.isEmpty)
                .padding(.horizontal, 16)
                
                // 5. Segments with Status Notification Badge
                Picker("Вкладки", selection: $selectedTab) {
                    Text("Headers (\(viewModel.headers.count))").tag(0)
                    Text("Query (\(viewModel.queryParams.count))").tag(1)
                    Text("Body").tag(2)
                    
                    if let resp = viewModel.response {
                        Text(resp.statusCode > 0 ? "Відповідь (\(resp.statusCode))" : "Відповідь ⚠️").tag(3)
                    } else {
                        Text("Відповідь").tag(3)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 2)
                
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
