import SwiftUI
import SwiftData

struct APIPreset: Identifiable {
    let id = UUID()
    let name: String
    let method: HTTPMethodType
    let url: String
    let description: String
    var headers: [RequestKeyValue] = [
        RequestKeyValue(key: "Content-Type", value: "application/json", isEnabled: true),
        RequestKeyValue(key: "Accept", value: "application/json", isEnabled: true)
    ]
    var queryParams: [RequestKeyValue] = []
    let sampleBody: String?
    var bodyType: BodyType = .none
    var sampleAssertions: [RequestAssertionItem] = []
}

public struct RequestBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SDEnvironment> { $0.isSelected }) private var activeEnvironments: [SDEnvironment]
    @Query(sort: \SDCollection.createdAt, order: .reverse) private var collections: [SDCollection]
    
    @State private var viewModel = RequestBuilderViewModel()
    @State private var selectedTab = 0 // 0: Params, 1: Auth, 2: Headers, 3: Body, 4: Tests, 5: Response
    @State private var showingSaveSheet = false
    @State private var requestSaveTitle = ""
    @State private var selectedCollectionForSave: SDCollection?
    @State private var showingNewColAlert = false
    @State private var newColName = ""
    @State private var showingUnsavedAlert = false
    @FocusState private var isInputFocused: Bool
    @State private var isURLFocused: Bool = false
    
    // Pasteboard observation & paste tracking
    @State private var hasClipboardContent: Bool = false
    @State private var lastPastedString: String? = nil
    @State private var justPasted: Bool = false
    
    // cURL State
    @State private var showingCURLImportSheet = false
    @State private var curlImportText = ""
    @State private var curlImportError: String?
    @State private var showCopiedToast = false
    @State private var showSavedToast = false
    @State private var savedTargetName = ""
    
    private let starterPresets: [APIPreset] = [
        APIPreset(
            name: "GET Todo",
            method: .get,
            url: "https://jsonplaceholder.typicode.com/todos/1",
            description: "GET single todo item by ID",
            headers: [
                RequestKeyValue(key: "Accept", value: "application/json", isEnabled: true)
            ],
            queryParams: [
                RequestKeyValue(key: "_v", value: "1.0", isEnabled: true)
            ],
            sampleBody: nil,
            bodyType: .none,
            sampleAssertions: [
                RequestAssertionItem(target: .statusCode, comparison: .equals, expectedValue: "200"),
                RequestAssertionItem(target: .responseTime, comparison: .lessThan, expectedValue: "3000"),
                RequestAssertionItem(target: .jsonKeyExists, comparison: .equals, expectedValue: "title"),
                RequestAssertionItem(target: .jsonValue, comparison: .equals, expectedValue: "1", keyPath: "id")
            ]
        ),
        APIPreset(
            name: "POST JSON",
            method: .post,
            url: "https://httpbin.org/post",
            description: "POST with JSON payload & custom headers",
            headers: [
                RequestKeyValue(key: "Content-Type", value: "application/json", isEnabled: true),
                RequestKeyValue(key: "X-Client-App", value: "APICraft-iOS", isEnabled: true)
            ],
            queryParams: [
                RequestKeyValue(key: "source", value: "mobile_app", isEnabled: true)
            ],
            sampleBody: "{\n  \"username\": \"alex_dev\",\n  \"role\": \"tester\",\n  \"active\": true\n}",
            bodyType: .json,
            sampleAssertions: [
                RequestAssertionItem(target: .statusCode, comparison: .equals, expectedValue: "200"),
                RequestAssertionItem(target: .jsonKeyExists, comparison: .equals, expectedValue: "json.username"),
                RequestAssertionItem(target: .jsonValue, comparison: .equals, expectedValue: "alex_dev", keyPath: "json.username"),
                RequestAssertionItem(target: .jsonValue, comparison: .equals, expectedValue: "mobile_app", keyPath: "args.source")
            ]
        ),
        APIPreset(
            name: "POST Form",
            method: .post,
            url: "https://httpbin.org/post",
            description: "POST x-www-form-urlencoded form data",
            headers: [
                RequestKeyValue(key: "Content-Type", value: "application/x-www-form-urlencoded", isEnabled: true)
            ],
            queryParams: [
                RequestKeyValue(key: "env", value: "staging", isEnabled: true)
            ],
            sampleBody: "email=user%40example.com&tier=premium&subscribe=true",
            bodyType: .urlEncoded,
            sampleAssertions: [
                RequestAssertionItem(target: .statusCode, comparison: .equals, expectedValue: "200"),
                RequestAssertionItem(target: .jsonKeyExists, comparison: .equals, expectedValue: "form.email"),
                RequestAssertionItem(target: .jsonValue, comparison: .equals, expectedValue: "premium", keyPath: "form.tier")
            ]
        ),
        APIPreset(
            name: "PUT Replace",
            method: .put,
            url: "https://httpbin.org/put",
            description: "PUT full entity update with JSON",
            headers: [
                RequestKeyValue(key: "Content-Type", value: "application/json", isEnabled: true),
                RequestKeyValue(key: "X-Trace-ID", value: "put-10029", isEnabled: true)
            ],
            queryParams: [
                RequestKeyValue(key: "replace", value: "true", isEnabled: true)
            ],
            sampleBody: "{\n  \"id\": 42,\n  \"title\": \"Updated Title\",\n  \"completed\": true\n}",
            bodyType: .json,
            sampleAssertions: [
                RequestAssertionItem(target: .statusCode, comparison: .equals, expectedValue: "200"),
                RequestAssertionItem(target: .jsonKeyExists, comparison: .equals, expectedValue: "json.title"),
                RequestAssertionItem(target: .jsonValue, comparison: .equals, expectedValue: "Updated Title", keyPath: "json.title"),
                RequestAssertionItem(target: .bodyContains, comparison: .contains, expectedValue: "put-10029")
            ]
        ),
        APIPreset(
            name: "PATCH Update",
            method: .patch,
            url: "https://httpbin.org/patch",
            description: "PATCH partial field modification",
            headers: [
                RequestKeyValue(key: "Content-Type", value: "application/json", isEnabled: true)
            ],
            queryParams: [
                RequestKeyValue(key: "patchMode", value: "partial", isEnabled: true)
            ],
            sampleBody: "{\n  \"status\": \"archived\"\n}",
            bodyType: .json,
            sampleAssertions: [
                RequestAssertionItem(target: .statusCode, comparison: .equals, expectedValue: "200"),
                RequestAssertionItem(target: .jsonValue, comparison: .equals, expectedValue: "archived", keyPath: "json.status"),
                RequestAssertionItem(target: .jsonValue, comparison: .equals, expectedValue: "partial", keyPath: "args.patchMode")
            ]
        ),
        APIPreset(
            name: "DELETE Item",
            method: .delete,
            url: "https://httpbin.org/delete",
            description: "DELETE resource with query confirmation",
            headers: [
                RequestKeyValue(key: "Accept", value: "application/json", isEnabled: true),
                RequestKeyValue(key: "X-Confirm-Delete", value: "yes", isEnabled: true)
            ],
            queryParams: [
                RequestKeyValue(key: "id", value: "991", isEnabled: true),
                RequestKeyValue(key: "hard", value: "false", isEnabled: true)
            ],
            sampleBody: nil,
            bodyType: .none,
            sampleAssertions: [
                RequestAssertionItem(target: .statusCode, comparison: .equals, expectedValue: "200"),
                RequestAssertionItem(target: .jsonKeyExists, comparison: .equals, expectedValue: "args.id"),
                RequestAssertionItem(target: .jsonValue, comparison: .equals, expectedValue: "991", keyPath: "args.id")
            ]
        ),
        APIPreset(
            name: "HEAD Headers",
            method: .head,
            url: "https://httpbin.org/get",
            description: "HEAD metadata request without response body",
            headers: [
                RequestKeyValue(key: "Accept", value: "*/*", isEnabled: true)
            ],
            queryParams: [
                RequestKeyValue(key: "test", value: "head_check", isEnabled: true)
            ],
            sampleBody: nil,
            bodyType: .none,
            sampleAssertions: [
                RequestAssertionItem(target: .statusCode, comparison: .equals, expectedValue: "200"),
                RequestAssertionItem(target: .header, comparison: .contains, expectedValue: "application/json", keyPath: "Content-Type")
            ]
        )
    ]
    
    public init() {}
    
    private var canPaste: Bool {
        guard hasClipboardContent else { return false }
        let currentTrimmed = viewModel.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentDecoded = currentTrimmed.removingPercentEncoding ?? currentTrimmed
        
        if let last = lastPastedString {
            if currentTrimmed == last || currentDecoded == last {
                return false
            }
        }
        return true
    }
    
    private var hasUnsavedChanges: Bool {
        let trimmed = viewModel.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDefaultURL = trimmed.isEmpty || trimmed == "https://" || trimmed == "https://jsonplaceholder.typicode.com/todos/1"
        if !isDefaultURL { return true }
        if !viewModel.queryParams.isEmpty { return true }
        if viewModel.bodyType != .none && !viewModel.bodyText.isEmpty { return true }
        if viewModel.authType != .none { return true }
        if viewModel.response != nil { return true }
        return false
    }
    
    private var activeTab: Int {
        if selectedTab == 5 && viewModel.response == nil {
            return 0
        }
        return selectedTab
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    environmentBanner
                    
                    // Request Command Hero Card
                    VStack(spacing: 12) {
                        methodChipsSection
                        urlInputSection
                        presetsSection
                        sendButtonSection
                    }
                    .padding(14)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    
                    // Segmented Navigation Bar
                    customTabBar
                        .padding(.horizontal, 16)
                    
                    // Tab Content Body
                    VStack {
                        switch activeTab {
                        case 0:
                            queryParamsTab
                        case 1:
                            authTab
                        case 2:
                            headersTab
                        case 3:
                            bodyTab
                        case 4:
                            testsTab
                        case 5:
                            responseTab
                        default:
                            queryParamsTab
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
            .overlay(alignment: .top) {
                toastOverlay
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if hasUnsavedChanges {
                            showingUnsavedAlert = true
                        } else {
                            viewModel.resetToNew()
                            lastPastedString = nil
                            selectedTab = 0
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 14, weight: .bold))
                            Text("New")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // cURL Menu (Export / Import)
                    Menu {
                        Button {
                            isInputFocused = false
                            let curl = viewModel.exportAsCURL()
                            UIPasteboard.general.string = curl
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring) {
                                showCopiedToast = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation {
                                    showCopiedToast = false
                                }
                            }
                        } label: {
                            Label("Copy as cURL", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            isInputFocused = false
                            curlImportText = ""
                            curlImportError = nil
                            showingCURLImportSheet = true
                        } label: {
                            Label("Import cURL...", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "terminal")
                            .font(.system(size: 15, weight: .medium))
                    }
                    
                    Button {
                        isInputFocused = false
                        requestSaveTitle = viewModel.title.isEmpty ? viewModel.resolveTitle() : viewModel.title
                        selectedCollectionForSave = collections.first
                        showingSaveSheet = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 15, weight: .medium))
                    }
                }
            }
            .alert("Unsaved Request", isPresented: $showingUnsavedAlert) {
                Button("Save to Collection") {
                    requestSaveTitle = viewModel.title.isEmpty ? viewModel.resolveTitle() : viewModel.title
                    selectedCollectionForSave = collections.first
                    showingSaveSheet = true
                }
                Button("Discard & Create New", role: .destructive) {
                    viewModel.resetToNew()
                    lastPastedString = nil
                    selectedTab = 0
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have unsaved changes in your current request. Do you want to save them to a collection or discard them?")
            }
            .sheet(isPresented: $showingSaveSheet) {
                saveToCollectionSheet
            }
            .sheet(isPresented: $showingCURLImportSheet) {
                curlImportSheet
            }
            .onAppear {
                refreshClipboardStatus()
                if let pending = AppNavigationState.shared.pendingLoadRequest {
                    viewModel.loadFrom(request: pending)
                    selectedTab = pending.bodyType != .none ? 3 : 0
                    AppNavigationState.shared.pendingLoadRequest = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
                lastPastedString = nil
                refreshClipboardStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                refreshClipboardStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                refreshClipboardStatus()
            }
            .onChange(of: AppNavigationState.shared.pendingLoadRequest) { _, newReq in
                if let req = newReq {
                    viewModel.loadFrom(request: req)
                    selectedTab = req.bodyType != .none ? 3 : 0
                    AppNavigationState.shared.pendingLoadRequest = nil
                }
            }
        }
    }
    
    @ViewBuilder
    private var environmentBanner: some View {
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
    }
    
    private var methodChipsSection: some View {
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
                            .background(isSelected ? color : color.opacity(0.14))
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
    }
    
    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
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
                    HStack(spacing: 4) {
                        Image(systemName: isHTTPS ? "lock.fill" : (isHTTP ? "lock.slash" : "globe"))
                            .font(.system(size: 12, weight: .bold))
                        Text(isHTTPS ? "HTTPS" : (isHTTP ? "HTTP" : "SCHEME"))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(isHTTPS ? Color.green : (isHTTP ? Color.orange : Color.secondary))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background((isHTTPS ? Color.green : (isHTTP ? Color.orange : Color.primary)).opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                
                DeselectableURLField(
                    text: $viewModel.url,
                    placeholder: "https://api.example.com/v1/resource",
                    onCommit: {
                        if viewModel.url.contains("?") {
                            viewModel.syncURLToParams()
                        }
                    },
                    onFocusChange: { focused in
                        isURLFocused = focused
                    }
                )
                .frame(minHeight: 34, maxHeight: 86)
                .padding(.vertical, 4)
                
                HStack(spacing: 6) {
                    if justPasted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                            Text("Pasted")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.14))
                        .foregroundStyle(Color.green)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.green.opacity(0.35), lineWidth: 1)
                        )
                    } else {
                        PasteButton(payloadType: String.self) { strings in
                            guard let rawPaste = strings.first?.trimmingCharacters(in: .whitespacesAndNewlines), !rawPaste.isEmpty else { return }
                            let cleanPaste = rawPaste.removingPercentEncoding ?? rawPaste
                            viewModel.url = cleanPaste
                            lastPastedString = cleanPaste
                            if cleanPaste.contains("?") {
                                viewModel.syncURLToParams()
                            } else {
                                viewModel.queryParams.removeAll()
                            }
                            withAnimation(.snappy) {
                                justPasted = true
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                withAnimation(.snappy) {
                                    justPasted = false
                                }
                            }
                        }
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .tint(canPaste ? Color.blue : Color.secondary.opacity(0.4))
                        .disabled(!canPaste)
                    }
                    
                    if !viewModel.url.isEmpty {
                        Button {
                            viewModel.url = ""
                            lastPastedString = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 6)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isURLFocused ? Color.blue.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: isURLFocused ? 1.5 : 1)
            )
            
            // Visual indicator showing that the URL field expands and is scrollable
            if viewModel.url.count > 35 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.and.down.text.horizontal")
                        .font(.system(size: 9, weight: .bold))
                    Text("Expands & scrollable")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    Spacer()
                    Text("\(viewModel.url.count) chars")
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .transition(.opacity)
            }
        }
    }
    
    private var presetsSection: some View {
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
                                viewModel.headers = preset.headers
                                viewModel.queryParams = preset.queryParams
                                viewModel.bodyType = preset.bodyType
                                viewModel.bodyText = preset.sampleBody ?? ""
                                viewModel.assertions = preset.sampleAssertions
                                viewModel.response = nil
                                viewModel.assertionLogs = []
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
    }
    
    private var sendButtonSection: some View {
        Button {
            isInputFocused = false
            Task {
                await viewModel.sendRequest(context: modelContext, activeEnv: activeEnvironments.first)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    selectedTab = 5 // Auto-switch to "Response"
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
    
    @ViewBuilder
    private var toastOverlay: some View {
        VStack(spacing: 8) {
            if showCopiedToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("cURL copied to clipboard")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if showSavedToast {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.checkmark")
                        .foregroundStyle(.blue)
                    Text("Saved to '\(savedTargetName)'")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, 8)
    }
    
    private func refreshClipboardStatus() {
        hasClipboardContent = UIPasteboard.general.hasStrings
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
    
    // MARK: - Custom Tab Bar (Dynamically displays Response tab ONLY when response exists)
    private var customTabBar: some View {
        HStack(spacing: 2) {
            tabButton(title: "Params", count: viewModel.queryParams.count, index: 0)
            tabButton(title: "Auth", count: viewModel.authType == .none ? nil : 1, index: 1)
            tabButton(title: "Headers", count: viewModel.headers.count, index: 2)
            tabButton(title: "Body", count: viewModel.bodyType == .none ? nil : 1, index: 3)
            tabButton(title: "Tests", count: viewModel.assertions.count, index: 4)
            if viewModel.response != nil {
                tabButton(title: "Response", count: nil, index: 5)
            }
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
                    .font(.system(size: 11, weight: selectedTab == index ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
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
                                .font(.caption)
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
    
    // MARK: - Auth Tab
    private var authTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Auth Type", selection: $viewModel.authType) {
                ForEach(RequestAuthType.allCases) { a in
                    Text(a.rawValue).tag(a)
                }
            }
            .pickerStyle(.segmented)
            
            switch viewModel.authType {
            case .none:
                VStack(spacing: 8) {
                    Image(systemName: "lock.open")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No Authorization")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("This request does not include any authorization headers.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.secondarySystemBackground).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
            case .bearer:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Bearer Token")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    TextField("Enter Token (or {{token}})", text: $viewModel.bearerToken, axis: .vertical)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .focused($isInputFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        .lineLimit(1...4)
                    
                    Text("The token will be added as: Authorization: Bearer <token>")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
            case .basic:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Basic Authentication")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Text("Username:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)
                        
                        TextField("admin", text: $viewModel.basicUsername)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .focused($isInputFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.asciiCapable)
                    }
                    
                    HStack(spacing: 8) {
                        Text("Password:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)
                        
                        SecureField("password", text: $viewModel.basicPassword)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .focused($isInputFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    Text("Credentials will be Base64-encoded into Authorization: Basic <base64>")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
            case .apiKey:
                VStack(alignment: .leading, spacing: 10) {
                    Text("API Key")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    Picker("Add To", selection: $viewModel.apiKeyLocation) {
                        ForEach(APIKeyLocation.allCases) { loc in
                            Text(loc.rawValue).tag(loc)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack(spacing: 8) {
                        TextField("Key Name (e.g. X-API-Key)", text: $viewModel.apiKeyName)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .focused($isInputFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.asciiCapable)
                        
                        TextField("Value", text: $viewModel.apiKeyValue)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .focused($isInputFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.asciiCapable)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Headers Tab
    private var headersTab: some View {
        VStack(spacing: 12) {
            HStack {
                Text("HTTP Headers")
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
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Custom Headers")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("Common headers like User-Agent and Host are sent automatically.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
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
                                    .font(.caption)
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
                HStack(spacing: 8) {
                    if viewModel.bodyType == .json {
                        Text("application/json")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    } else if viewModel.bodyType == .urlEncoded {
                        Text("x-www-form-urlencoded")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    } else if viewModel.bodyType == .formData {
                        Text("multipart/form-data")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.12))
                            .foregroundStyle(.purple)
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
    
    // MARK: - Tests / Assertions Tab
    private var testsTab: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("+ Status 200") {
                        withAnimation {
                            viewModel.assertions.append(RequestAssertionItem(target: .statusCode, comparison: .equals, expectedValue: "200"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("+ Key 'title'") {
                        withAnimation {
                            viewModel.assertions.append(RequestAssertionItem(target: .jsonKeyExists, comparison: .equals, expectedValue: "title", keyPath: "title"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("+ JSON 'id' == 1") {
                        withAnimation {
                            viewModel.assertions.append(RequestAssertionItem(target: .jsonValue, comparison: .equals, expectedValue: "1", keyPath: "id"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("+ Time < 1000ms") {
                        withAnimation {
                            viewModel.assertions.append(RequestAssertionItem(target: .responseTime, comparison: .lessThan, expectedValue: "1000"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("+ Body contains") {
                        withAnimation {
                            viewModel.assertions.append(RequestAssertionItem(target: .bodyContains, comparison: .contains, expectedValue: "title"))
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
                            
                            Menu {
                                Picker("Target", selection: Binding(
                                    get: { bindableItem.target },
                                    set: { newTarget in
                                        bindableItem.target = newTarget
                                        switch newTarget {
                                        case .statusCode:
                                            bindableItem.expectedValue = "200"
                                            bindableItem.comparison = .equals
                                        case .responseTime:
                                            bindableItem.expectedValue = "1000"
                                            bindableItem.comparison = .lessThan
                                        case .header:
                                            if bindableItem.keyPath == nil || bindableItem.keyPath?.isEmpty == true {
                                                bindableItem.keyPath = "Content-Type"
                                            }
                                            bindableItem.expectedValue = "application/json"
                                            bindableItem.comparison = .contains
                                        case .bodyContains:
                                            bindableItem.expectedValue = "title"
                                            bindableItem.comparison = .contains
                                        case .jsonKeyExists:
                                            bindableItem.expectedValue = "title"
                                            bindableItem.keyPath = "title"
                                            bindableItem.comparison = .equals
                                        case .jsonValue:
                                            if bindableItem.keyPath == nil || bindableItem.keyPath?.isEmpty == true {
                                                bindableItem.keyPath = "id"
                                            }
                                            bindableItem.expectedValue = "1"
                                            bindableItem.comparison = .equals
                                        }
                                    }
                                )) {
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
                        
                        if bindableItem.target == .statusCode {
                            HStack(spacing: 8) {
                                Text("Status:")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 75, alignment: .leading)
                                
                                TextField("200", text: $bindableItem.expectedValue)
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(8)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .focused($isInputFocused)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.asciiCapableNumberPad)
                            }
                        } else if bindableItem.target == .responseTime {
                            HStack(spacing: 8) {
                                Text("Max (ms):")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 75, alignment: .leading)
                                
                                TextField("1000", text: $bindableItem.expectedValue)
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(8)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .focused($isInputFocused)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.asciiCapableNumberPad)
                            }
                        } else if bindableItem.target == .bodyContains {
                            HStack(spacing: 8) {
                                Text("Substring:")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 75, alignment: .leading)
                                
                                TextField("e.g. title or userId", text: $bindableItem.expectedValue)
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(8)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .focused($isInputFocused)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.asciiCapable)
                            }
                        } else if bindableItem.target == .jsonKeyExists {
                            HStack(spacing: 8) {
                                Text("Key Path:")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 75, alignment: .leading)
                                
                                TextField("e.g. title or id", text: $bindableItem.expectedValue)
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(8)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .focused($isInputFocused)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.asciiCapable)
                                    .onChange(of: bindableItem.expectedValue) {
                                        bindableItem.keyPath = bindableItem.expectedValue
                                    }
                            }
                        } else if bindableItem.target == .jsonValue {
                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Text("Key Path:")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 75, alignment: .leading)
                                    
                                    TextField("e.g. id or title", text: Binding(
                                        get: { bindableItem.keyPath ?? "" },
                                        set: { bindableItem.keyPath = $0 }
                                    ))
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(8)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .focused($isInputFocused)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.asciiCapable)
                                }
                                
                                HStack(spacing: 8) {
                                    Text("Expected:")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 75, alignment: .leading)
                                    
                                    TextField("e.g. 1 or true", text: $bindableItem.expectedValue)
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
                        } else if bindableItem.target == .header {
                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Text("Header:")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    .frame(width: 75, alignment: .leading)
                                    
                                    TextField("e.g. Content-Type", text: Binding(
                                        get: { bindableItem.keyPath ?? "" },
                                        set: { bindableItem.keyPath = $0 }
                                    ))
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(8)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .focused($isInputFocused)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.asciiCapable)
                                }
                                
                                HStack(spacing: 8) {
                                    Text("Expected:")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 75, alignment: .leading)
                                    
                                    TextField("e.g. application/json", text: $bindableItem.expectedValue)
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
                
                if let err = resp.error, !err.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.title3)
                            .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Network Error")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red)
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Assertions Results Card
                if !viewModel.assertionLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        let passedCount = viewModel.assertionLogs.filter { $0.isPassed }.count
                        let totalCount = viewModel.assertionLogs.count
                        let allPassed = passedCount == totalCount
                        
                        HStack {
                            Image(systemName: allPassed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(allPassed ? .green : .red)
                            Text("Tests: \(passedCount)/\(totalCount) Passed")
                                .font(.subheadline.bold())
                                .foregroundStyle(allPassed ? .green : .red)
                            Spacer()
                        }
                        
                        Divider()
                        
                        ForEach(Array(viewModel.assertionLogs.enumerated()), id: \.offset) { _, log in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: log.isPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(log.isPassed ? .green : .red)
                                    .font(.caption.bold())
                                    .padding(.top, 2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(log.description)
                                        .font(.caption.bold())
                                        .foregroundStyle(.primary)
                                    
                                    if let fail = log.failureReason {
                                        Text(fail)
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                if let body = resp.body, !body.isEmpty {
                    Text("Response Body")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    JSONSyntaxView(rawJSON: resp.body ?? "")
                }
                
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
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
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
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingSaveSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let targetCol = selectedCollectionForSave ?? collections.first
                        if let col = targetCol {
                            viewModel.saveToCollection(collection: col, customTitle: requestSaveTitle, context: modelContext)
                            savedTargetName = col.name
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            withAnimation(.spring) {
                                showSavedToast = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation {
                                    showSavedToast = false
                                }
                            }
                        }
                        showingSaveSheet = false
                    }
                    .disabled(requestSaveTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (selectedCollectionForSave == nil && collections.isEmpty))
                }
            }
            .onAppear {
                if selectedCollectionForSave == nil {
                    selectedCollectionForSave = collections.first
                }
                if requestSaveTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    requestSaveTitle = viewModel.title.isEmpty ? viewModel.resolveTitle() : viewModel.title
                }
            }
            .alert("New Collection", isPresented: $showingNewColAlert) {
                TextField("Collection Name", text: $newColName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                Button("Create") {
                    let trimmed = newColName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let col = SDCollection(name: trimmed)
                    modelContext.insert(col)
                    do {
                        try modelContext.save()
                    } catch {
                        print("❌ Failed to create collection: \(error)")
                    }
                    selectedCollectionForSave = col
                    newColName = ""
                }
                Button("Cancel", role: .cancel) {
                    newColName = ""
                }
            }
        }
    }
    
    // MARK: - cURL Import Sheet
    private var curlImportSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Paste any cURL command from Chrome DevTools, Postman, or terminal:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                TextEditor(text: $curlImportText)
                    .font(.system(size: 12, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .frame(minHeight: 180)
                
                if let err = curlImportError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
                
                PasteButton(payloadType: String.self) { strings in
                    if let paste = strings.first {
                        curlImportText = paste
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                .buttonBorderShape(.capsule)
                .controlSize(.regular)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Import cURL")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCURLImportSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        if viewModel.importFromCURL(curlImportText) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            showingCURLImportSheet = false
                            selectedTab = viewModel.bodyType != .none ? 3 : 0
                        } else {
                            curlImportError = "Invalid cURL command. Make sure it starts with 'curl'."
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        }
                    }
                    .disabled(curlImportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.headline)
                }
            }
        }
    }
}
