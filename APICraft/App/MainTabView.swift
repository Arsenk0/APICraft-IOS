import SwiftUI
import SwiftData

@Observable
final class AppNavigationState {
    static let shared = AppNavigationState()
    var selectedTab: Int = 0
    var pendingLoadRequest: SDRequest?
    
    func openInBuilder(request: SDRequest) {
        self.pendingLoadRequest = request
        self.selectedTab = 0
    }
}

public struct MainTabView: View {
    @AppStorage("hasSeedDataLoaded") private var hasSeedDataLoaded = false
    @Environment(\.modelContext) private var modelContext
    @Bindable private var navState = AppNavigationState.shared
    
    public init() {}

    public var body: some View {
        TabView(selection: $navState.selectedTab) {
            RequestBuilderView()
                .tabItem {
                    Label("Requests", systemImage: "paperplane.fill")
                }
                .tag(0)

            CollectionsListView()
                .tabItem {
                    Label("Collections", systemImage: "folder.fill")
                }
                .tag(1)

            HistoryListView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(2)

            EnvironmentListView()
                .tabItem {
                    Label("Environments", systemImage: "slider.horizontal.3")
                }
                .tag(3)
        }
        .onAppear {
            seedDefaultDataIfNeeded()
        }
        .dismissKeyboardOnTap()
    }
    
    private func seedDefaultDataIfNeeded() {
        guard !hasSeedDataLoaded else { return }
        hasSeedDataLoaded = true
        
        // 1. Starter Environment
        let env = SDEnvironment(name: "JSONPlaceholder (Dev)", isSelected: true)
        let v1 = SDEnvironmentVariable(key: "baseUrl", value: "https://jsonplaceholder.typicode.com")
        let v2 = SDEnvironmentVariable(key: "sampleId", value: "1")
        env.variables = [v1, v2]
        modelContext.insert(env)
        
        // 2. Starter Collection
        let col = SDCollection(name: "Sample REST API", details: "Starter endpoints with automated validation assertions")
        
        // Request 1: GET
        let req1 = SDRequest(
            title: "GET Single Todo",
            urlTemplate: "{{baseUrl}}/todos/{{sampleId}}",
            method: .get,
            bodyType: .none,
            isHistoryItem: false
        )
        req1.collection = col
        req1.keyValues.append(SDRequestParameter(key: "Accept", value: "application/json", location: .header))
        req1.assertions.append(SDTestAssertion(target: .statusCode, comparison: .equals, expectedValue: "200"))
        req1.assertions.append(SDTestAssertion(target: .responseTime, comparison: .lessThan, expectedValue: "2500"))
        req1.assertions.append(SDTestAssertion(target: .jsonKeyExists, keyPath: "title", comparison: .equals, expectedValue: "title"))
        req1.assertions.append(SDTestAssertion(target: .jsonValue, keyPath: "id", comparison: .equals, expectedValue: "1"))
        
        // Request 2: POST
        let req2 = SDRequest(
            title: "POST Create Post",
            urlTemplate: "{{baseUrl}}/posts",
            method: .post,
            bodyType: .json,
            rawBodyContent: "{\n  \"title\": \"APICraft iOS\",\n  \"body\": \"Clean Swift Concurrency Network Engine\",\n  \"userId\": 1\n}",
            isHistoryItem: false
        )
        req2.collection = col
        req2.keyValues.append(SDRequestParameter(key: "Content-Type", value: "application/json", location: .header))
        req2.assertions.append(SDTestAssertion(target: .statusCode, comparison: .equals, expectedValue: "201"))
        req2.assertions.append(SDTestAssertion(target: .jsonKeyExists, keyPath: "id", comparison: .equals, expectedValue: "id"))
        
        col.requests = [req1, req2]
        modelContext.insert(col)
        
        try? modelContext.save()
    }
}
