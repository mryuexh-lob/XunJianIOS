import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @State private var latest: AppVersion?
    @State private var checking = false
    @State private var showUpdateInfo = false
    @State private var showForce = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.brand)
                Text("电力巡检安全测试靶场").font(.title3).bold()
                Text("版本 \(appVersion())").foregroundColor(.gray)
                Text("服务器：\(TokenManager.serverURL)")
                    .font(.footnote).foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button { checkUpdate() } label: {
                    if checking { ProgressView() } else { Text("检查更新") }
                }
                .frame(maxWidth: .infinity).padding(12)
                .background(Color.brand).foregroundColor(.white).cornerRadius(10)
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 30)
            .navigationTitle("关于")
            .navigationBarItems(trailing: Button("关闭") { dismiss() })
            .alert("发现新版本", isPresented: $showUpdateInfo) {
                Button("确定") { if latest?.forceUpdate == true { showForce = true } }
            } message: { Text(updateText()) }
            .alert("强制更新", isPresented: $showForce) {
                Button("我知道了") { }
            } message: { Text("当前版本过低，必须更新后才能使用。") }
        }
    }

    func appVersion() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (build \(b))"
    }
    func checkUpdate() {
        checking = true
        Task {
            do {
                latest = try await APIClient.shared.checkUpdate()
                await MainActor.run { showUpdateInfo = true }
            } catch {
                latest = nil
            }
            await MainActor.run { checking = false }
        }
    }
    func updateText() -> String {
        guard let v = latest else { return "已是最新版本" }
        return "最新版本：\(v.versionName ?? "")\n更新内容：\(v.updateContent ?? "")"
    }
}
