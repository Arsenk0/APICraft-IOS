import SwiftUI
import SwiftData

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
                        
                        // Adaptive URL Input Field with Scheme Selector
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
                                .font(.system(size: 14, design: .monospaced))
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
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Send Request Hero Button
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
                    
                    // 3. Custom Segmented Navigation Bar (Params, Headers, Body, Tests, Response)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                tabButton(title: "Params", count: viewModel.queryParams.count, index: 0)
                tabButton(title: "Headers", count: viewModel.headers.count, index: 1)
                tabButton(title: "Body", count: viewModel.bodyType == .none ? nil : 1, index: 2)
                tabButton(title: "Tests", count: viewModel.assertions.count, index: 3)
                tabButton(title: "Response", count: viewModel.response != nil ? 1 : nil, index: 4)
            }
            .padding(4)
        }
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func tabButton(title: String, count: Int?, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: selectedTab == index ? .bold : .medium))
                    .lineLimit(1)
                
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(selectedTab == index ? Color.blue : Color.secondary.opacity(0.25))
                        .foregroundStyle(selectedTab == index ? Color.white : Color.primary)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
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
                        .padding(.top, 4)
                    }
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
                                .onChange(of: bindableItem.isEnabled) {
                                    viewModel.syncParamsToURL()
                                }
                            
                            Text(item.key.isEmpty ? "New Parameter" : item.key)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(item.isEnabled ? .primary : .secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
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
                        
                        HStack(spacing: 8) {
                            TextField("Key (e.g. limit)", text: $bindableItem.key)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(8)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isInputFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.asciiCapable)
                                .onChange(of: bindableItem.key) {
                                    viewModel.syncParamsToURL()
                                }
                            
                            TextField("Value (e.g. 10)", text: $bindableItem.value)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(8)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isInputFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.asciiCapable)
                                .onChange(of: bindableItem.value) {
                                    viewModel.syncParamsToURL()
                                }
                        }
                    }
                    .padding(10)
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
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Headers")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("Add request headers such as Accept, Authorization, or Content-Type.")
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
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(item.isEnabled ? .primary : .secondary)
                                .lineLimit(1)
                            
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
    
    // MARK: - Tests / Assertions Tab (Dynamic user-configurable test suite)
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("", isOn: $bindableItem.isEnabled)
                                .labelsHidden()
                                .tint(.green)
                            
                            Picker("Target", selection: $bindableItem.target) {
                                ForEach(AssertionTarget.allCases) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            
                            Picker("Comparison", selection: $bindableItem.comparison) {
                                ForEach(AssertionComparison.allCases) { c in
                                    Text(c.rawValue).tag(c)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
                                    viewModel.assertions.removeAll(where: { $0.id == item.id })
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        HStack(spacing: 8) {
                            Text("Expected:")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            
                            TextField("e.g. 200 or 500", text: $bindableItem.expectedValue)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(8)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .focused($isInputFocused)
                                .autocorrectionDisabled()
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
                
                // Response Body with JSON Viewer
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Response Body:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let body = resp.body, !body.isEmpty {
                            Button {
                                UIPasteboard.general.string = body
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                        }
                    }
                    
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
                        .padding(.top, 4)
                    }
                    .font(.caption.bold())
                    .padding(12)
                    .background(Color(.secondarySystemBackground).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    TextField(viewModel.resolveTitle(), text: $requestSaveTitle)
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
