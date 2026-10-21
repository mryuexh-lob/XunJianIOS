import SwiftUI

/// 用户管理（仅 ADMIN）。展示账号、姓名、角色、联系方式。
struct UserListView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var users: [AdminUser] = []
    @State private var busy = false
    @State private var errorMsg: String?
    @State private var showError = false

    var body: some View {
        NavigationView {
            Group {
                if busy && users.isEmpty {
                    ProgressView()
                } else if users.isEmpty {
                    Text("暂无用户").foregroundColor(.gray)
                } else {
                    List(users) { u in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(u.realName ?? u.username ?? "\(u.id)").font(.headline)
                            HStack {
                                Text("账号：\(u.username ?? "-")").font(.caption).foregroundColor(.gray)
                                Text(roleName(u.role)).font(.caption).foregroundColor(.gray)
                            }
                            if let p = u.phone, !p.isEmpty {
                                Text("电话：\(p)").font(.caption).foregroundColor(.gray)
                            }
                            if let e = u.email, !e.isEmpty {
                                Text("邮箱：\(e)").font(.caption).foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("用户管理")
            .navigationBarItems(leading: Button("关闭") { presentationMode.wrappedValue.dismiss() })
            .onAppear { Task { await load() } }
            .alert(isPresented: $showError) {
                Alert(title: Text("错误"), message: Text(errorMsg ?? ""),
                      dismissButton: .default(Text("确定")))
            }
        }
        .navigationViewStyle(.stack)
    }

    func load() async {
        busy = true; errorMsg = nil
        do { users = try await APIClient.shared.adminUsers() }
        catch { errorMsg = error.localizedDescription; showError = true }
        busy = false
    }
    func roleName(_ r: String?) -> String {
        switch r {
        case "ADMIN":   return "系统管理员"
        case "AUDITOR": return "审计管理员"
        case "USER":    return "检修员"
        default:        return r ?? "-"
        }
    }
}
