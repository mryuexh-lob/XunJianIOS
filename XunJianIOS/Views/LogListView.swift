import SwiftUI

/// 操作日志（ADMIN / AUDITOR 可用）。展示业务与系统日志统计及明细。
struct LogListView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var logs: [OpLog] = []
    @State private var stats: LogStats?
    @State private var keyword = ""
    @State private var username = ""
    @State private var busy = false
    @State private var errorMsg: String?
    @State private var showError = false

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("关键字", text: $keyword).textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("用户名", text: $username).textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("搜索") { Task { await load() } }
                }
                .padding(.horizontal, 12).padding(.top, 8)

                if let s = stats {
                    HStack(spacing: 12) {
                        Text("业务 \(s.business ?? 0)").font(.caption)
                        Text("系统 \(s.system ?? 0)").font(.caption)
                        Spacer()
                        Text("合计 \(s.total ?? 0)").font(.caption).bold()
                    }
                    .padding(.horizontal, 12)
                }

                if busy && logs.isEmpty {
                    ProgressView()
                } else if logs.isEmpty {
                    Spacer()
                    Text("暂无日志").foregroundColor(.gray)
                    Spacer()
                } else {
                    List(logs) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(log.action ?? "-").font(.headline)
                                Spacer()
                                Text(log.level ?? "").font(.caption).foregroundColor(.gray)
                            }
                            if let u = log.username, !u.isEmpty {
                                Text("用户：\(u)").font(.caption).foregroundColor(.gray)
                            }
                            if let d = log.detail, !d.isEmpty {
                                Text(d).font(.caption).foregroundColor(.gray)
                            }
                            HStack {
                                if let ip = log.ip, !ip.isEmpty {
                                    Text(ip).font(.caption2).foregroundColor(.gray)
                                }
                                Spacer()
                                Text(log.createTime ?? "").font(.caption2).foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("操作日志")
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
        do {
            let resp = try await APIClient.shared.logs(keyword: keyword, username: username)
            logs = resp.list ?? []
            stats = resp.stats
        } catch {
            errorMsg = error.localizedDescription; showError = true
        }
        busy = false
    }
}
