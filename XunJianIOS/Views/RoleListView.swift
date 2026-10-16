import SwiftUI

/// 角色权限管理（仅 ADMIN）。展示角色编码、名称、备注与菜单权限。
struct RoleListView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var roles: [RoleInfo] = []
    @State private var busy = false
    @State private var errorMsg: String?
    @State private var showError = false

    var body: some View {
        NavigationView {
            Group {
                if busy && roles.isEmpty {
                    ProgressView()
                } else if roles.isEmpty {
                    Text("暂无角色").foregroundColor(.gray)
                } else {
                    List(roles) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(r.name ?? r.code ?? "\(r.id)").font(.headline)
                            HStack {
                                Text("编码：\(r.code ?? "-")").font(.caption).foregroundColor(.gray)
                                if let remark = r.remark, !remark.isEmpty {
                                    Text(remark).font(.caption).foregroundColor(.gray)
                                }
                            }
                            if let m = r.menus, !m.isEmpty {
                                Text("菜单：\(m)").font(.caption).foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("权限管理")
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
        do { roles = try await APIClient.shared.adminRoles() }
        catch { errorMsg = error.localizedDescription; showError = true }
        busy = false
    }
}
