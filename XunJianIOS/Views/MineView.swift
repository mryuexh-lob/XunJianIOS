import SwiftUI

struct MineView: View {
    @EnvironmentObject var appState: AppState
    @State private var user: UserInfo?
    @State private var showChangePwd = false
    @State private var showAbout = false
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
                        Button { showChangePwd = true } label: {
                            Label("修改密码", systemImage: "lock.rotation")
                        }
                        Button { showAbout = true } label: {
                            Label("关于", systemImage: "info.circle")
                        }
                    }
                    Section {
                        Button(role: .destructive) { appState.logout() } label: {
                            Label("退出登录", systemImage: "arrow.backward.square")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("我的")
            .navigationBarHidden(true)
            .onAppear { Task { await load() } }
            .sheet(isPresented: $showChangePwd) { ChangePasswordView() }
            .sheet(isPresented: $showAbout)    { AboutView() }
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
