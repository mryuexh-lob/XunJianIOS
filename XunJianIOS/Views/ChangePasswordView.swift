import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var oldPwd = ""
    @State private var newPwd = ""
    @State private var confirmPwd = ""
    @State private var busy = false
    @State private var errorMsg: String?
    @State private var showError = false
    @State private var success = false

    var body: some View {
        NavigationView {
            Form {
                Section("修改密码") {
                    SecureField("原密码", text: $oldPwd)
                    SecureField("新密码", text: $newPwd)
                    SecureField("确认新密码", text: $confirmPwd)
                }
            }
            .navigationTitle("修改密码")
            .navigationBarItems(leading: Button("取消") { presentationMode.wrappedValue.dismiss() },
                                trailing: Button("保存") { submit() })
            .alert(isPresented: $showError) {
                Alert(title: Text("提示"), message: Text(errorMsg ?? ""),
                      dismissButton: .default(Text("确定")))
            }
            .alert("修改成功", isPresented: $success) {
                Button("确定") { presentationMode.wrappedValue.dismiss() }
            } message: {
                Text("密码已修改（注意：服务端未校验复杂度，弱口令可直接生效）")
            }
        }
    }
    func submit() {
        guard !oldPwd.isEmpty else { errorMsg = "请输入原密码"; showError = true; return }
        guard !newPwd.isEmpty else { errorMsg = "请输入新密码"; showError = true; return }
        guard !confirmPwd.isEmpty else { errorMsg = "请输入确认新密码"; showError = true; return }
        guard newPwd == confirmPwd else { errorMsg = "两次输入的新密码不一致"; showError = true; return }

        busy = true
        Task {
            do {
                try await APIClient.shared.changePassword(old: oldPwd, new: newPwd)
                await MainActor.run { success = true }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription; showError = true }
            }
            await MainActor.run { busy = false }
        }
    }
}
