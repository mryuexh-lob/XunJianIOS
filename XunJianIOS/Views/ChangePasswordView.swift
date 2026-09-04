import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var oldPwd = ""
    @State private var newPwd = ""
    @State private var busy = false
    @State private var errorMsg: String?
    @State private var showError = false
    @State private var success = false

    var body: some View {
        NavigationView {
            Form {
                SecureField("原密码", text: $oldPwd)
                SecureField("新密码", text: $newPwd)
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
        guard !oldPwd.isEmpty, !newPwd.isEmpty else {
            errorMsg = "请填写原密码和新密码"; showError = true; return
        }
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
