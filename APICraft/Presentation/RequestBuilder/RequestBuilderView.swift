import SwiftUI
import SwiftData

public struct RequestBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SDEnvironment> { $0.isSelected }) private var activeEnvironments: [SDEnvironment]
    @Query(sort: \SDCollection.name) private var collections: [SDCollection]
    
    @State private var viewModel = RequestBuilderViewModel()
    @State private var selectedTab = 0 // 0: Headers, 1: Params, 2: Body, 3: Response
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
                            Text("Environment: \(activeEnv.name)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
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
                                        withAnimation(.snappy(duration: 0.2)) {
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
                        
                        // Adaptive Multi-Line URL Input Field with Scheme Selector
                        HStack(alignment: .top, spacing: 8) {
                            Menu {
                                Button("https://") {
                                    setURLScheme("https://")
                                }
                                Button("http://") {
                                    setURLScheme("http://")
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: viewModel.url.hasPrefix("https://") ? "lock.fill" : "globe")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(viewModel.url.hasPrefix("http://") ? "HTTP" : "HTTPS")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                            
                            TextField("api.example.com/v1/resource", text: $viewModel.url, axis: .vertical)
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.asciiCapable)
                                .focused($isInputFocused)
                                .lineLimit(1...4)
                                .padding(.vertical, 4)
                            
                            if !viewModel.url.isEmpty {
                                Button {
                                    viewModel.url = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 6)
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
                                .padding(.top, 6)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Send Request Hero Button
                        Button {
                            isInputFocused = false
                            Task {
                                await viewModel.sendRequest(context: modelContext, activeEnv: activeEnvironments.first)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedTab = 3 // Auto-switch to "Response"
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
                                    Text("Sending...")
                                        .font(.system(size: 16, weight: .bold))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("Send Request")
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [
                                        MethodBadgeView.color(for: viewModel.method),
                                        MethodBadgeView.color(for: viewModel.method).opacity(0.85)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: MethodBadgeView.color(for: viewModel.method).opacity(0.35), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isLoading || viewModel.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(viewModel.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                    }
                    .padding(14)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    
                    // 3. Custom Segmented Navigation Bar (Clean & balanced, no status badges)
                    customTabBar
                        .padding(.horizontal, 16)
                    
                    // 4. Tab Content Body
                    VStack {
                        switch selectedTab {
                        case 0:
                            headersTab
                        case 1:
                            queryParamsTab
                        case 2:
                            bodyTab
                        case 3:
                            responseTab
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .padding(.top, 8)
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
                        Label("Save", systemImage: "folder.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingSaveSheet) {
                saveToCollectionSheet
            }
        }
    }
    
    private func setURLScheme(_ scheme: String) {
        if viewModel.url.hasPrefix("https://") {
            viewModel.url = scheme + viewModel.url.dropFirst("https://".count)
        } else if viewModel.url.hasPrefix("http://") {
            viewModel.url = scheme + viewModel.url.dropFirst("http://".count)
        } else {
            viewModel.url = scheme + viewModel.url
        }
    }
    
    // MARK: - Custom Tab Bar
    private var customTabBar: some View {
        HStack(spacing: 6) {
            tabButton(title: "Headers", count: viewModel.headers.count, index: 0)
            tabButton(title: "Params", count: viewModel.queryParams.count, index: 1)
            tabButton(title: "Body", count: viewModel.bodyText.isEmpty ? nil : 1, index: 2)
            tabButton(title: "Response", count: nil, index: 3)
        }
        .padding(4)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func tabButton(title: String, count: Int?, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: selectedTab == index ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
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
            .padding(.horizontal, 4)
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
    
    // MARK: - Headers Tab
    private var headersTab: some View {
        VStack(spacing: 12) {
            if viewModel.headers.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Headers")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("Tap the button below to add request headers (e.g. Accept, Content-Type).")
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
                            
                            Text(item.key.isEmpty ? "New Header" : item.key)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(item.isEnabled ? .primary : .secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
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
                            TextField("Key (e.g. Accept)", text: $bindableItem.key)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(9)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isInputFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.asciiCapable)
                                .lineLimit(1)
                            
                            TextField("Value (e.g. application/json)", text: $bindableItem.value)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(9)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isInputFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.asciiCapable)
                                .lineLimit(1)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Button {
                withAnimation {
                    viewModel.headers.append(RequestKeyValue(key: "", value: "", isEnabled: true))
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Header")
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
    private var queryParamsTab: some View {
        VStack(spacing: 12) {
            if viewModel.queryParams.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Query Parameters")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("Parameters will be appended to the URL as ?key=value")
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
                            
                            Text(item.key.isEmpty ? "New Parameter" : item.key)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(item.isEnabled ? .primary : .secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
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
                            TextField("Key (e.g. page)", text: $bindableItem.key)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(9)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isInputFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.asciiCapable)
                                .lineLimit(1)
                            
                            TextField("Value (e.g. 1)", text: $bindableItem.value)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(9)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isInputFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.asciiCapable)
                                .lineLimit(1)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Button {
                withAnimation {
                    viewModel.queryParams.append(RequestKeyValue(key: "", value: "", isEnabled: true))
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Parameter")
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
                Text("Body Format:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                Picker("Body Type", selection: $viewModel.bodyType) {
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
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
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
    
    // MARK: - Response Tab (All response status and metrics shown here cleanly)
    private var responseTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let resp = viewModel.response {
                // Metrics Card
                HStack(spacing: 8) {
                    StatusBadgeView(statusCode: resp.statusCode, showText: true)
                    
                    Spacer(minLength: 4)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption)
                        Text(String(format: "%.0f ms", resp.durationMs))
                            .font(.caption.bold().monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.caption)
                        Text("\(resp.sizeBytes) B")
                            .font(.caption.bold().monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Assertions (if any)
                if !viewModel.assertionLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assertions:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        
                        ForEach(viewModel.assertionLogs) { log in
                            HStack(spacing: 8) {
                                Image(systemName: log.isPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(log.isPassed ? .green : .red)
                                Text(log.description)
                                    .font(.caption)
                                    .lineLimit(2)
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
                    Text("Response Body:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    JSONSyntaxView(rawJSON: resp.body ?? "")
                }
            } else {
                ContentUnavailableView(
                    "No Response Yet",
                    systemImage: "paperplane.circle",
                    description: Text("Tap 'Send Request' above to execute this request and view response data.")
                )
                .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Save Sheet
    private var saveToCollectionSheet: some View {
        NavigationStack {
            Form {
                Section("Request Name") {
                    TextField("e.g. Get User Profile", text: $requestSaveTitle)
                        .focused($isInputFocused)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                }
                
                Section("Collection") {
                    if collections.isEmpty {
                        Text("No collections created yet.")
                            .foregroundStyle(.secondary)
                        Button("Create New Collection") {
                            showingNewColAlert = true
                        }
                    } else {
                        Picker("Choose Collection", selection: $selectedCollectionForSave) {
                            ForEach(collections) { col in
                                Text(col.name).tag(Optional(col))
                            }
                        }
                        
                        Button {
                            showingNewColAlert = true
                        } label: {
                            Label("Create Another Collection", systemImage: "plus")
                        }
                    }
                }
            }
            .navigationTitle("Save Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingSaveSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
            .alert("New Collection", isPresented: $showingNewColAlert) {
                TextField("Collection Name", text: $newColName)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                Button("Create") {
                    let trimmed = newColName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let newCol = SDCollection(name: trimmed)
                        modelContext.insert(newCol)
                        try? modelContext.save()
                        selectedCollectionForSave = newCol
                        newColName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newColName = ""
                }
            }
        }
        .presentationDetents([.medium])
    }
}
