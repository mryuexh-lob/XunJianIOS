import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var username = ""
    @State private var password = ""
    @State private var server   = TokenManager.serverURL
    @State private var errorMsg: String?
    @State private var busy = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.brand)
                    Text("电力巡检安全测试靶场")
                        .font(.title2).bold()
                    Text("移动巡检 · 安全测试样品")
                        .font(.footnote).foregroundColor(.gray)
                }
                .padding(.top, 40)

                VStack(spacing: 14) {
                    TextField("服务器地址", text: $server)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    TextField("账号", text: $username)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    SecureField("密码", text: $password)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal, 24)

                if let errorMsg = errorMsg {
                    Text(errorMsg).foregroundColor(.red).font(.footnote)
                        .padding(.horizontal, 24)
                }

                Button(action: doLogin) {
                    if busy {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("登 录").foregroundColor(.white).bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color.brand)
                .cornerRadius(10)
                .padding(.horizontal, 24)
                .disabled(busy)

                Spacer()
            }
            .navigationBarHidden(true)
        }
    }

    func doLogin() {
        busy = true; errorMsg = nil
        Task {
            do {
                TokenManager.serverURL = server.trimmingCharacters(in: .whitespaces)
                let resp = try await APIClient.shared.login(username: username, password: password)
                TokenManager.saveLogin(resp)
                await MainActor.run { appState.login() }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription }
            }
            await MainActor.run { busy = false }
        }
    }
}
