import SwiftUI
import SwiftData

struct APIPreset: Identifiable {
    let id = UUID()
    let name: String
    let method: HTTPMethodType
    let url: String
    let description: String
    let sampleBody: String?
}

public struct RequestBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SDEnvironment> { $0.isSelected }) private var activeEnvironments: [SDEnvironment]
    @Query(sort: \SDCollection.createdAt, order: .reverse) private var collections: [SDCollection]
    
    @State private var viewModel = RequestBuilderViewModel()
    @State private var selectedTab = 0 // 0: Params, 1: Headers, 2: Body, 3: Tests, 4: Response
    @State private var showingSaveSheet = false
    @State private var requestSaveTitle = ""
    @State private var selectedCollectionForSave: SDCollection?
    @State private var showingNewColAlert = false
    @State private var newColName = ""
    @FocusState private var isInputFocused: Bool
    
    private let starterPresets: [APIPreset] = [
        APIPreset(name: "Todos", method: .get, url: "https://jsonplaceholder.typicode.com/todos/1", description: "GET single todo item", sampleBody: nil),
        APIPreset(name: "Users", method: .get, url: "https://jsonplaceholder.typicode.com/users", description: "GET list of users", sampleBody: nil),
        APIPreset(name: "Create Post", method: .post, url: "https://jsonplaceholder.typicode.com/posts", description: "POST new resource", sampleBody: "{\n  \"title\": \"foo\",\n  \"body\": \"bar\",\n  \"userId\": 1\n}"),
        APIPreset(name: "ReqRes Users", method: .get, url: "https://reqres.in/api/users?page=2", description: "GET paginated users", sampleBody: nil),
        APIPreset(name: "Status 200", method: .get, url: "https://httpbin.org/status/200", description: "HTTPBin 200 OK test", sampleBody: nil),
        APIPreset(name: "UUID Gen", method: .get, url: "https://httpbin.org/uuid", description: "HTTPBin UUID generator", sampleBody: nil),
        APIPreset(name: "Cat Fact", method: .get, url: "https://catfact.ninja/fact", description: "Random daily cat fact", sampleBody: nil)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Environment Banner
                    if let activeEnv = activeEnvironments.first {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                            Text("Environment: \(activeEnv.name)")
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(activeEnv.variables.count) vars")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 16)
                    }
                    
                    // 2. Request Command Hero Card
                    VStack(spacing: 12) {
                        // Method Selector Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(HTTPMethodType.allCases) { m in
                                    let isSelected = viewModel.method == m
                                    let color = MethodBadgeView.color(for: m)
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.snappy(duration: 0.2)) {
                                            viewModel.method = m
                                            if (m == .post || m == .put || m == .patch) && viewModel.bodyType == .none {
                                                viewModel.bodyType = .json
                                            }
                                        }
                                    } label: {
                                        Text(m.rawValue)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(
                                                isSelected
                                                    ? color
                                                    : color.opacity(0.14)
                                            )
                                            .foregroundStyle(isSelected ? Color.white : color)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        
                        // Adaptive URL Input Field with Interactive Scheme Switcher
                        HStack(alignment: .center, spacing: 6) {
                            let isHTTPS = viewModel.url.lowercased().hasPrefix("https://")
                            let isHTTP = viewModel.url.lowercased().hasPrefix("http://")
                            
                            Menu {
                                Button {
                                    switchProtocol(to: "https://")
                                } label: {
                                    Label("https:// (Secure SSL)", systemImage: "lock.fill")
                                }
                                Button {
                                    switchProtocol(to: "http://")
                                } label: {
                                    Label("http:// (Unencrypted / Local)", systemImage: "lock.slash")
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: isHTTPS ? "lock.fill" : (isHTTP ? "lock.slash" : "globe"))
                                        .font(.system(size: 11, weight: .bold))
                                    Text(isHTTPS ? "HTTPS" : (isHTTP ? "HTTP" : "SCHEME"))
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 7, weight: .bold))
                                }
                                .foregroundStyle(isHTTPS ? Color.green : (isHTTP ? Color.orange : Color.secondary))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 5)
                                .background((isHTTPS ? Color.green : (isHTTP ? Color.orange : Color.primary)).opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                            
                            TextField("https://api.example.com/v1/resource", text: $viewModel.url, axis: .vertical)
                                .font(.system(size: 14, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.asciiCapable)
                                .focused($isInputFocused)
                                .lineLimit(1...3)
                                .padding(.vertical, 8)
                            
                            if !viewModel.url.isEmpty {
                                Button {
                                    viewModel.url = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 8)
                            } else if UIPasteboard.general.hasStrings {
                                Button {
                                    if let pasteString = UIPasteboard.general.string {
                                        viewModel.url = pasteString
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                } label: {
                                    Text("Paste")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.primary.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 8)
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        // Starter API presets for beginners
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label("Quick API Presets", systemImage: "sparkles")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(starterPresets) { preset in
                                        Button {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            withAnimation(.snappy) {
                                                viewModel.method = preset.method
                                                viewModel.url = preset.url
                                                if let body = preset.sampleBody {
                                                    viewModel.bodyType = .json
                                                    viewModel.bodyText = body
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(preset.method.rawValue)
                                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(MethodBadgeView.color(for: preset.method))
                                                Text(preset.name)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundStyle(.primary)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.secondarySystemBackground))
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        // Execute Request Button
                        Button {
                            isInputFocused = false
                            Task {
                                await viewModel.sendRequest(context: modelContext, activeEnv: activeEnvironments.first)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedTab = 4 // Auto-switch to "Response"
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
                                        .font(.system(size: 15, weight: .bold))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Send Request")
                                        .font(.system(size: 15, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
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
                            .shadow(color: MethodBadgeView.color(for: viewModel.method).opacity(0.3), radius: 6, y: 2)
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
                    
                    // 3. Segmented Navigation Bar (All tabs fit neatly without truncation)
                    customTabBar
                        .padding(.horizontal, 16)
                    
                    // 4. Tab Content Body
                    VStack {
                        switch selectedTab {
                        case 0:
                            queryParamsTab
                        case 1:
                            headersTab
                        case 2:
                            bodyTab
                        case 3:
                            testsTab
                        case 4:
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
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    isInputFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            )
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("APICraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isInputFocused = false
                        requestSaveTitle = viewModel.title.isEmpty ? viewModel.resolveTitle() : viewModel.title
                        selectedCollectionForSave = collections.first
                        showingSaveSheet = true
                    } label: {
                        Label("Save", systemImage: "folder.badge.plus")
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(["https://", "/api/v1/", "/users", "?page=1", "&limit=10", ".json", ".com", "localhost:8080"], id: \.self) { snippet in
                                Button(snippet) {
                                    viewModel.url += snippet
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button("Done") {
                        isInputFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(.subheadline.bold())
                }
            }
            .sheet(isPresented: $showingSaveSheet) {
                saveToCollectionSheet
            }
            .onAppear {
                if let pending = AppNavigationState.shared.pendingLoadRequest {
                    viewModel.loadFrom(request: pending)
                    AppNavigationState.shared.pendingLoadRequest = nil
                }
            }
            .onChange(of: AppNavigationState.shared.pendingLoadRequest) { _, newReq in
                if let req = newReq {
                    viewModel.loadFrom(request: req)
                    AppNavigationState.shared.pendingLoadRequest = nil
                }
            }
        }
    }
    
    private func switchProtocol(to scheme: String) {
        let lower = viewModel.url.lowercased()
        if lower.hasPrefix("https://") {
            viewModel.url = scheme + viewModel.url.dropFirst("https://".count)
        } else if lower.hasPrefix("http://") {
            viewModel.url = scheme + viewModel.url.dropFirst("http://".count)
        } else {
            viewModel.url = scheme + viewModel.url
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // MARK: - Custom Tab Bar (Fits neatly on all device widths)
    private var customTabBar: some View {
        HStack(spacing: 3) {
            tabButton(title: "Params", count: viewModel.queryParams.count, index: 0)
            tabButton(title: "Headers", count: viewModel.headers.count, index: 1)
            tabButton(title: "Body", count: viewModel.bodyType == .none ? nil : 1, index: 2)
            tabButton(title: "Tests", count: viewModel.assertions.count, index: 3)
            tabButton(title: "Response", count: viewModel.response != nil ? 1 : nil, index: 4)
        }
        .padding(3)
        .background(Color(.secondarySystemBackground).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func tabButton(title: String, count: Int?, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: selectedTab == index ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(selectedTab == index ? Color.blue : Color.secondary.opacity(0.25))
                        .foregroundStyle(selectedTab == index ? Color.white : Color.primary)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(selectedTab == index ? Color(.systemBackground) : Color.clear)
            .foregroundStyle(selectedTab == index ? Color.primary : Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: selectedTab == index ? Color.black.opacity(0.06) : Color.clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Query Params Tab
    private var queryParamsTab: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Query Parameters")
                    .font(.subheadline.bold())
                Spacer()
                if !viewModel.queryParams.isEmpty {
                    Button("Clear All") {
                        withAnimation {
                            viewModel.queryParams.removeAll()
                            viewModel.syncParamsToURL()
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
            
            if viewModel.queryParams.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Query Parameters")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("Parameters are automatically appended to the URL as ?key=value")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    
                    if viewModel.url.contains("?") {
                        Button("Import Parameters from URL") {
                            withAnimation {
                                viewModel.syncURLToParams()
                            }
                        }
                        .font(.caption.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(viewModel.queryParams) { item in
                    @Bindable var bindableItem = item
                    HStack(spacing: 8) {
                        Toggle("", isOn: $bindableItem.isEnabled)
                            .labelsHidden()
                            .tint(.blue)
                            .onChange(of: bindableItem.isEnabled) {
                                viewModel.syncParamsToURL()
                            }
                        
                        TextField("Key", text: $bindableItem.key)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .focused($isInputFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.asciiCapable)
                            .onChange(of: bindableItem.key) {
                                viewModel.syncParamsToURL()
                            }
                        
                        TextField("Value", text: $bindableItem.value)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .focused($isInputFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.asciiCapable)
                            .onChange(of: bindableItem.value) {
                                viewModel.syncParamsToURL()
                            }
                        
                        Button {
                            withAnimation {
                                viewModel.queryParams.removeAll(where: { $0.id == item.id })
                                viewModel.syncParamsToURL()
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
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
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Headers Tab
    private var headersTab: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Headers")
                    .font(.subheadline.bold())
                Spacer()
                if !viewModel.headers.isEmpty {
                    Button("Clear All") {
                        withAnimation {
                            viewModel.headers.removeAll()
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
            
            if viewModel.headers.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Headers Configured")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("Standard HTTP headers like Content-Type or Authorization can be defined here.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            } else {
                ForEach(viewModel.headers) { item in
                    @Bindable var bindableItem = item
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Toggle("", isOn: $bindableItem.isEnabled)
                                .labelsHidden()
                                .tint(.blue)
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
                                    viewModel.headers.removeAll(where: { $0.id == item.id })
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        HStack(spacing: 8) {
                            TextField("Header Name (e.g. Accept)", text: $bindableItem.key)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(8)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isInputFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.asciiCapable)
                            
                            TextField("Value (e.g. application/json)", text: $bindableItem.value)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(8)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isInputFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.asciiCapable)
                        }
                    }
                    .padding(10)
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
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Body Tab
    private var bodyTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Body Format Selector
            Picker("Body Format", selection: $viewModel.bodyType) {
                ForEach(BodyType.allCases) { b in
                    Text(b.rawValue).tag(b)
                }
            }
            .pickerStyle(.segmented)
            
            if viewModel.bodyType == .none {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No Body Configured")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("GET and HEAD requests typically do not carry a payload.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    
                    Button("Switch to Raw JSON") {
                        withAnimation {
                            viewModel.setJSONTemplate()
                        }
                    }
                    .font(.caption.bold())
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.secondarySystemBackground).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Toolbar above text editor
                HStack(spacing: 8) {
                    if viewModel.bodyType == .json {
                        Text("application/json")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    if viewModel.bodyType == .json {
                        Button {
                            viewModel.formatJSONBody()
                        } label: {
                            Label("Beautify", systemImage: "sparkles")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        
                        Button {
                            viewModel.setJSONTemplate()
                        } label: {
                            Label("Template", systemImage: "curlybraces")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                    
                    if !viewModel.bodyText.isEmpty {
                        Button("Clear") {
                            viewModel.bodyText = ""
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
                
                TextEditor(text: $viewModel.bodyText)
                    .font(.system(size: 13, design: .monospaced))
                    .focused($isInputFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    .padding(8)
                    .frame(minHeight: 180)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Tests / Assertions Tab (Balanced full-width controls)
    private var testsTab: some View {
        VStack(spacing: 12) {
            // Quick Presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("+ Status 200") {
                        withAnimation {
                            viewModel.assertions.append(RequestAssertionItem(target: .statusCode, comparison: .equals, expectedValue: "200"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("+ Status 201") {
                        withAnimation {
                            viewModel.assertions.append(RequestAssertionItem(target: .statusCode, comparison: .equals, expectedValue: "201"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("+ Time < 500ms") {
                        withAnimation {
                            viewModel.assertions.append(RequestAssertionItem(target: .responseTime, comparison: .lessThan, expectedValue: "500"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("+ Body contains") {
                        withAnimation {
                            viewModel.assertions.append(RequestAssertionItem(target: .bodyContains, comparison: .contains, expectedValue: "id"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            if viewModel.assertions.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.shield")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Assertions Configured")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("Add assertions above to automatically validate response status, response time, or body content.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            } else {
                ForEach(viewModel.assertions) { item in
                    @Bindable var bindableItem = item
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Toggle("", isOn: $bindableItem.isEnabled)
                                .labelsHidden()
                                .tint(.green)
                            
                            // Target selector that stretches flexibly to fill space
                            Menu {
                                Picker("Target", selection: $bindableItem.target) {
                                    ForEach(AssertionTarget.allCases) { t in
                                        Text(t.rawValue).tag(t)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(bindableItem.target.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color(.tertiarySystemBackground))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Comparison operator selector or stable badge
                            if bindableItem.target != .bodyContains {
                                Menu {
                                    Picker("Comparison", selection: $bindableItem.comparison) {
                                        ForEach(AssertionComparison.allCases) { c in
                                            Text(c.rawValue).tag(c)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 3) {
                                        Text(bindableItem.comparison.rawValue)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(minWidth: 44)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 7)
                                    .background(Color(.tertiarySystemBackground))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            } else {
                                Text("contains")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 7)
                                    .background(Color(.tertiarySystemBackground).opacity(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            Button {
                                withAnimation {
                                    viewModel.assertions.removeAll(where: { $0.id == item.id })
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red.opacity(0.85))
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        HStack(spacing: 8) {
                            Text(bindableItem.target == .bodyContains ? "Substring:" : "Expected:")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 75, alignment: .leading)
                            
                            TextField(
                                bindableItem.target == .statusCode ? "200" :
                                (bindableItem.target == .responseTime ? "500" : "text to match"),
                                text: $bindableItem.expectedValue
                            )
                            .font(.system(size: 13, design: .monospaced))
                            .padding(8)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .focused($isInputFocused)
                            .autocorrectionDisabled()
                            .keyboardType(bindableItem.target == .statusCode || bindableItem.target == .responseTime ? .numberPad : .asciiCapable)
                        }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Button {
                withAnimation {
                    viewModel.assertions.append(RequestAssertionItem(target: .statusCode, comparison: .equals, expectedValue: "200"))
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Custom Test")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Response Tab
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
                
                // Error Card (if any failure occurred)
                if let err = resp.error, !err.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.title3)
                            .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Request Failed")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red)
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Assertions Results (Dynamic Evaluation)
                if !viewModel.assertionLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        let passedCount = viewModel.assertionLogs.filter { $0.isPassed }.count
                        HStack {
                            Text("Test Results")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(passedCount)/\(viewModel.assertionLogs.count) Passed")
                                .font(.caption2.bold())
                                .foregroundStyle(passedCount == viewModel.assertionLogs.count ? .green : .orange)
                        }
                        
                        ForEach(viewModel.assertionLogs) { log in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: log.isPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(log.isPassed ? .green : .red)
                                    .padding(.top, 1)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(log.description)
                                        .font(.caption.bold())
                                    if let fail = log.failureReason {
                                        Text(fail)
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
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
                
                // Response Body Viewer (Clean with single Copy button inside card)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Response Body")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    JSONSyntaxView(rawJSON: resp.body ?? "")
                }
                
                // Response Headers (collapsible)
                if !resp.headers.isEmpty {
                    DisclosureGroup("Response Headers (\(resp.headers.count))") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(resp.headers.keys.sorted()), id: \.self) { key in
                                HStack(alignment: .top) {
                                    Text(key)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(resp.headers[key] ?? "")
                                        .font(.system(size: 12, design: .monospaced))
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 2)
                                Divider()
                            }
                        }
                        .padding(.top, 8)
                    }
                    .font(.caption.bold())
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.badge.clock")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Response Yet")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("Tap 'Send Request' to execute this request and view real-time metrics, tests, headers, and body.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Save to Collection Sheet
    private var saveToCollectionSheet: some View {
        NavigationStack {
            Form {
                Section("Request Title") {
                    TextField("Title", text: $requestSaveTitle)
                        .focused($isInputFocused)
                }
                
                Section("Collection") {
                    if collections.isEmpty {
                        Text("No collections available. Create one below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Collection", selection: $selectedCollectionForSave) {
                            ForEach(collections) { col in
                                Text(col.name).tag(col as SDCollection?)
                            }
                        }
                    }
                    
                    Button {
                        showingNewColAlert = true
                    } label: {
                        Label("New Collection", systemImage: "plus")
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
                        if let col = selectedCollectionForSave {
                            viewModel.saveToCollection(collection: col, customTitle: requestSaveTitle, context: modelContext)
                        }
                        showingSaveSheet = false
                    }
                    .disabled(requestSaveTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCollectionForSave == nil)
                }
            }
            .alert("New Collection", isPresented: $showingNewColAlert) {
                TextField("Collection Name", text: $newColName)
                Button("Create") {
                    let col = SDCollection(name: newColName)
                    modelContext.insert(col)
                    try? modelContext.save()
                    selectedCollectionForSave = col
                    newColName = ""
                }
                Button("Cancel", role: .cancel) {
                    newColName = ""
                }
            }
        }
    }
}
