import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab = 0
    
    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            RequestBuilderView()
                .tabItem {
                    Label("Запити", systemImage: "paperplane.fill")
                }
                .tag(0)

            CollectionsListView()
                .tabItem {
                    Label("Колекції", systemImage: "folder.fill")
                }
                .tag(1)

            HistoryListView()
                .tabItem {
                    Label("Історія", systemImage: "clock.arrow.circlepath")
                }
                .tag(2)

            EnvironmentListView()
                .tabItem {
                    Label("Середовища", systemImage: "slider.horizontal.3")
                }
                .tag(3)
        }
    }
}
