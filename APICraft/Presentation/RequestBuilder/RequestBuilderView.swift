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
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Active Environment Pill Banner
                    if let activeEnv = activeEnvironments.first {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Середовище: \(activeEnv.name)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // 2. Request Setup Card (Method Selector + URL + Send Button)
                    VStack(spacing: 12) {
                        // Horizontal Method Bar with Full-Fill Colors
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(HTTPMethodType.allCases) { m in
                                    let isSelected = viewModel.method == m
                                    let color = MethodBadgeView.color(for: m)
                                    
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        _ = withAnimation(.snappy(duration: 0.2)) {
                                            viewModel.method = m
                                        }
                                    } label: {
                                        Text(m.rawValue)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                isSelected
                                                    ? color
                                                    : color.opacity(0.16)
                                            )
                                            .foregroundStyle(isSelected ? Color.white : color)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(color.opacity(isSelected ? 0 : 0.35), lineWidth: 1)
                                            )
                                            .shadow(color: isSelected ? color.opacity(0.35) : .clear, radius: 4, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        
                        // Spacious URL Input Field
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            TextField("https://api.example.com/v1/resource", text: $viewModel.url)
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
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
                                .buttonStyle(.plain)
                            } else if UIPasteboard.general.hasStrings {
                                Button {
                                    if let pasteString = UIPasteboard.general.string {
                                        viewModel.url = pasteString
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Send Request Hero Button
                        Button {
                            isInputFocused = false
                            Task {
                                await viewModel.sendRequest(context: modelContext, activeEnv: activeEnvironments.first)
                                _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
                            .padding(.vertical, 14)
                            .background(
                                viewModel.url.isEmpty
                                    ? Color.gray.opacity(0.3)
                                    : Color.blue
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: viewModel.url.isEmpty ? .clear : Color.blue.opacity(0.35), radius: 6, y: 3)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isLoading || viewModel.url.isEmpty)
                    }
                    .padding(14)
                    .background(Color(.tertiarySystemBackground).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    
                    // 3. Custom Tab Bar with Live Status Badges
                    customTabBar
                        .padding(.horizontal, 16)
                    
                    // 4. Active Tab Content
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
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 10)
            }
            .scrollDismissesKeyboard(.interactively)
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
                
                // Keyboard Accessory Toolbar (above the keyboard letters)
                ToolbarItemGroup(placement: .keyboard) {
                    keyboardAccessoryBar
                }
            }
            .sheet(isPresented: $showingSaveSheet) {
                saveToCollectionSheet
            }
        }
    }
    
    // MARK: - Custom Tab Bar
    private var customTabBar: some View {
        HStack(spacing: 8) {
            tabButton(title: "Заголовки", count: viewModel.headers.count, index: 0)
            tabButton(title: "Параметри", count: viewModel.queryParams.count, index: 1)
            tabButton(title: "Тіло", count: viewModel.bodyText.isEmpty ? nil : 1, index: 2)
            
            // Response Tab with Live Status Badge
            Button {
                _ = withAnimation(.spring(response: 0.25)) {
                    selectedTab = 3
                }
            } label: {
                HStack(spacing: 5) {
                    Text("Відповідь")
                        .font(.system(size: 13, weight: selectedTab == 3 ? .bold : .medium))
                    
                    if let resp = viewModel.response {
                        Text("\(resp.statusCode)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(resp.statusCode >= 200 && resp.statusCode < 300 ? Color.green : Color.red)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == 3 ? Color(.secondarySystemBackground) : Color.clear)
                .foregroundStyle(selectedTab == 3 ? Color.primary : Color.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selectedTab == 3 ? Color.primary.opacity(0.12) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func tabButton(title: String, count: Int?, index: Int) -> some View {
        Button {
            _ = withAnimation(.spring(response: 0.25)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: selectedTab == index ? .bold : .medium))
                
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.2))
                        .foregroundStyle(Color.blue)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectedTab == index ? Color(.secondarySystemBackground) : Color.clear)
            .foregroundStyle(selectedTab == index ? Color.primary : Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedTab == index ? Color.primary.opacity(0.12) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Keyboard Accessory Bar ("над буквами в швидкому виборі")
    private var keyboardAccessoryBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Clipboard quick suggestion pill
                    if let clip = UIPasteboard.general.string, !clip.isEmpty {
                        Button {
                            if viewModel.url.isEmpty {
                                viewModel.url = clip
                            } else {
                                UIPasteboard.general.string = clip
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.clipboard.fill")
                                Text("Вставити: \"\(clip.prefix(16))\(clip.count > 16 ? "..." : "")\"")
                                    .lineLimit(1)
                            }
                            .font(.caption2.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.18))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    quickSnippetButton(title: "https://") {
                        if !viewModel.url.hasPrefix("https://") {
                            viewModel.url = "https://" + viewModel.url
                        }
                    }
                    
                    quickSnippetButton(title: "application/json") {
                        if let existing = viewModel.headers.first(where: { $0.key.lowercased() == "content-type" || $0.key.lowercased() == "accept" }) {
                            existing.value = "application/json"
                        } else {
                            viewModel.headers.append(RequestKeyValue(key: "Content-Type", value: "application/json", isEnabled: true))
                        }
                    }
                    
                    quickSnippetButton(title: "Bearer Token") {
                        viewModel.headers.append(RequestKeyValue(key: "Authorization", value: "Bearer ", isEnabled: true))
                    }
                    
                    quickSnippetButton(title: "{{base_url}}") {
                        viewModel.url += "{{base_url}}"
                    }
                    
                    quickSnippetButton(title: "?") {
                        viewModel.url += "?"
                    }
                    
                    quickSnippetButton(title: "&") {
                        viewModel.url += "&"
                    }
                    
                    quickSnippetButton(title: "=") {
                        viewModel.url += "="
                    }
                }
                .padding(.vertical, 2)
            }
            
            Spacer()
            
            // Dismiss Keyboard button (clean native icon)
            Button {
                isInputFocused = false
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                    .padding(6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private func quickSnippetButton(title: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.caption2.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .foregroundStyle(.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Headers Tab
    private var headersTab: some View {
        VStack(spacing: 12) {
            if viewModel.headers.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Заголовки відсутні")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Натисніть кнопку нижче, щоб додати заголовок запиту (напр. Accept, Content-Type).")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            } else {
                ForEach(viewModel.headers) { item in
                    @Bindable var bindableItem = item
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("", isOn: $bindableItem.isEnabled)
                                .labelsHidden()
                                .tint(.blue)
                            
                            Text(item.key.isEmpty ? "Новий заголовок" : item.key)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(item.isEnabled ? .primary : .secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button {
                                _ = withAnimation {
                                    viewModel.headers.removeAll(where: { $0.id == item.id })
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        HStack(spacing: 8) {
                            TextField("Key (Accept)", text: $bindableItem.key)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(9)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isInputFocused)
                            
                            TextField("Value (application/json)", text: $bindableItem.value)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(9)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isInputFocused)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Button {
                _ = withAnimation {
                    viewModel.headers.append(RequestKeyValue(key: "", value: "", isEnabled: true))
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Додати заголовок")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Query Params Tab
    private var queryTab: some View {
        VStack(spacing: 12) {
            if viewModel.queryParams.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "questionmark.folder")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Параметри запиту відсутні")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Параметри додаються до URL у форматі ?key=value")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            } else {
                ForEach(viewModel.queryParams) { item in
                    @Bindable var bindableItem = item
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("", isOn: $bindableItem.isEnabled)
                                .labelsHidden()
                                .tint(.blue)
                            
                            Text(item.key.isEmpty ? "Новий параметр" : item.key)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(item.isEnabled ? .primary : .secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button {
                                _ = withAnimation {
                                    viewModel.queryParams.removeAll(where: { $0.id == item.id })
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        HStack(spacing: 8) {
                            TextField("Параметр (напр. page)", text: $bindableItem.key)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(9)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isInputFocused)
                            
                            TextField("Значення (напр. 1)", text: $bindableItem.value)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(9)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isInputFocused)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Button {
                _ = withAnimation {
                    viewModel.queryParams.append(RequestKeyValue(key: "", value: "", isEnabled: true))
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Додати параметр")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Body Tab
    private var bodyTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Формат тіла:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                Picker("Тип тіла", selection: $viewModel.bodyType) {
                    ForEach(BodyType.allCases) { b in
                        Text(b.rawValue).tag(b)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
            }
            
            TextEditor(text: $viewModel.bodyText)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .focused($isInputFocused)
                .padding(10)
                .frame(minHeight: 180)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Response Tab
    private var responseTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let resp = viewModel.response {
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
                
                // Assertions (if any)
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
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Body Content with JSON Viewer
                VStack(alignment: .leading, spacing: 8) {
                    Text("Тіло відповіді:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    JSONSyntaxView(rawJSON: resp.body ?? "")
                }
            } else {
                ContentUnavailableView(
                    "Немає відповіді",
                    systemImage: "paperplane.circle",
                    description: Text("Натисніть кнопку 'Надіслати запит' угорі, щоб виконати запит та отримати результат.")
                )
                .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Save Sheet
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
