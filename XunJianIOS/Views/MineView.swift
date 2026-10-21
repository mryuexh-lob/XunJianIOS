import SwiftUI

/// 我的页弹窗：收敛为一个枚举 + 单个 `.sheet(item:)`，
/// 避免同一视图叠多个 `.sheet` 时点 A 弹出 B（或点了没反应）。
enum MineSheet: String, Identifiable {
    case changePwd, about, logs, users, roles
    var id: String { rawValue }
}

struct MineView: View {
    @EnvironmentObject var appState: AppState
    @State private var user: UserInfo?
    @State private var activeSheet: MineSheet?
    @State private var errorMsg: String?
    @State private var showError = false

    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.brand)
                    Text(user?.realName ?? user?.username ?? "未登录")
                        .font(.title3).bold()
                    Text(roleName(user?.role)).font(.footnote).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.brand.opacity(0.08))

                List {
                    Section {
                        if TokenManager.canAccess("/system/log") {
                            Button { activeSheet = .logs } label: {
                                Label("操作日志", systemImage: "doc.text.magnifyingglass")
                            }
                        }
                        if TokenManager.canAccess("/system/user") {
                            Button { activeSheet = .users } label: {
                                Label("用户管理", systemImage: "person.2")
                            }
                        }
                        if TokenManager.canAccess("/system/role") {
                            Button { activeSheet = .roles } label: {
                                Label("权限管理", systemImage: "key")
                            }
                        }
                    }
                    Section {
                        Button { activeSheet = .changePwd } label: {
                            Label("修改密码", systemImage: "lock.rotation")
                        }
                        Button { activeSheet = .about } label: {
                            Label("关于", systemImage: "info.circle")
                        }
                    }
                    Section {
                        Button { appState.logout() } label: {
                            Label("退出登录", systemImage: "arrow.backward.square")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.red)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("我的")
            .navigationBarHidden(true)
            .onAppear { Task { await load() } }
            .sheet(item: $activeSheet) { kind in
                switch kind {
                case .changePwd: ChangePasswordView()
                case .about:     AboutView()
                case .logs:      LogListView()
                case .users:     UserListView()
                case .roles:     RoleListView()
                }
            }
            .alert(isPresented: $showError) {
                Alert(title: Text("错误"), message: Text(errorMsg ?? ""),
                      dismissButton: .default(Text("确定")))
            }
        }
        .navigationViewStyle(.stack)
    }

    func load() async {
        do { user = try await APIClient.shared.me() }
        catch { errorMsg = error.localizedDescription; showError = true }
    }
    func roleName(_ r: String?) -> String {
        switch r {
        case "ADMIN":   return "系统管理员"
        case "AUDITOR": return "审计管理员"
        case "USER":    return "巡检员"
        default:        return r ?? "用户"
        }
    }
}
