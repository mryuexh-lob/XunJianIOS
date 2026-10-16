import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // 审计管理员（AUDITOR）无巡检菜单，仅"我的"中查看操作日志
            if TokenManager.canAccess("/inspection/task") {
                TaskListView()
                    .tabItem { Label("巡检", systemImage: "mappin.and.ellipse") }
            }

            MineView()
                .tabItem { Label("我的", systemImage: "person") }
        }
        .accentColor(.brand)
    }
}
