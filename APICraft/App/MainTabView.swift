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
    }
}
