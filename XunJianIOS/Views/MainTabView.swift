import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TaskListView()
                .tabItem { Label("巡检", systemImage: "mappin.and.ellipse") }

            MineView()
                .tabItem { Label("我的", systemImage: "person") }
        }
        .accentColor(.brand)
    }
}
