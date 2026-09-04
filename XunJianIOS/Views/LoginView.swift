import SwiftUI

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var username = ""
    @State private var password = ""
    @State private var errorMsg: String?
    @State private var busy = false
    @State private var showServerSheet = false
    @State private var toast: String?
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.brand)
                            Text("电力巡检助手")
                                .font(.title2).bold()
                            Text("移动智能巡检平台")
                                .font(.footnote).foregroundColor(.gray)
                        }
                        .padding(.top, 30)

                        VStack(spacing: 14) {
                            TextField("请输入账号", text: $username)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .submitLabel(.next)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            SecureField("请输入密码", text: $password)
                                .submitLabel(.go)
                                .onSubmit { doLogin() }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 24)

                        if let errorMsg = errorMsg {
                            Text(errorMsg)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        Button(action: doLogin) {
                            if busy {
                                HStack(spacing: 8) {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("登录中…").foregroundColor(.white)
                                }
                            } else {
                                Text("登 录").foregroundColor(.white).bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.brand)
                        .cornerRadius(10)
                        .contentShape(Rectangle())
                        .padding(.horizontal, 24)
                        .disabled(busy)

                        Button(action: { UIApplication.shared.endEditing(); showServerSheet = true }) {
                            Text("服务器设置").font(.footnote).foregroundColor(.blue)
                        }
                        .padding(.top, 4)

                        Spacer(minLength: 20)
                    }
                    // 键盘弹出时把内容整体顶高，避免登录按钮被键盘盖住
                    .padding(.bottom, keyboardHeight)
                    .animation(.easeOut(duration: 0.25), value: keyboardHeight)
                }
                // 点击空白处收起键盘
                .onTapGesture { UIApplication.shared.endEditing() }

                if let t = toast {
                    VStack {
                        Spacer()
                        Text(t)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(8)
                            .padding(.bottom, 80)
                    }
                    .transition(.opacity)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showServerSheet) {
                ServerSettingsSheet()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { n in
                if let f = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = f.height
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
        }
    }

    func showToast(_ msg: String) {
        toast = msg
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run { toast = nil }
        }
    }

    func doLogin() {
        UIApplication.shared.endEditing()
        busy = true; errorMsg = nil
        let url = TokenManager.serverURL.trimmingCharacters(in: .whitespaces)
        if url.isEmpty {
            errorMsg = "请先在「服务器设置」中填写后端地址"; busy = false; return
        }
        if username.isEmpty { errorMsg = "请输入账号"; busy = false; return }
        if password.isEmpty { errorMsg = "请输入密码"; busy = false; return }

        Task {
            do {
                let resp = try await APIClient.shared.login(username: username, password: password)
                await MainActor.run {
                    TokenManager.saveLogin(resp)
                    busy = false
                    showToast("登录成功")
                    appState.login()
                }
            } catch {
                let e = error as NSError
                await MainActor.run {
                    busy = false
                    errorMsg = "登录失败（错误码 \(e.code)）\n\(e.localizedDescription)\n当前服务器：\(TokenManager.serverURL)"
                }
            }
        }
    }
}

// MARK: - 服务器设置弹窗（与安卓「我的-服务器设置」页面对齐）
struct ServerSettingsSheet: View {
    @State private var serverText = TokenManager.serverURL
    @State private var testResult = ""
    @State private var testing = false
    @State private var toastMsg: String?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("服务器地址").font(.headline)
                            Text("示例：192.168.1.10:8080 或 http://192.168.1.10:8080")
                                .font(.caption).foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                        TextField("http://服务器IP:端口", text: $serverText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .submitLabel(.done)
                            .onSubmit { UIApplication.shared.endEditing() }
                            .padding(.horizontal)

                        Button(action: save) {
                            Text("保存").bold()
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.brand).foregroundColor(.white).cornerRadius(8)
                        }
                        .padding(.horizontal)

                        Button(action: testConnection) {
                            HStack {
                                if testing { ProgressView() }
                                Text(testing ? "测试中…" : "测试连接").bold()
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.blue.opacity(0.12)).foregroundColor(.blue).cornerRadius(8)
                        }
                        .disabled(testing)
                        .padding(.horizontal)

                        if !testResult.isEmpty {
                            Text(testResult)
                                .font(.caption)
                                .foregroundColor(testResult.hasPrefix("✅") ? .green : .red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                        }

                        Button(action: clear) {
                            Text("清空地址").bold()
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.red.opacity(0.15)).foregroundColor(.red).cornerRadius(8)
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 20)
                    }
                    .padding(.top)
                }
                .onTapGesture { UIApplication.shared.endEditing() }

                if let t = toastMsg {
                    VStack {
                        Spacer()
                        Text(t)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(8)
                            .padding(.bottom, 60)
                    }
                }
            }
            .navigationTitle("服务器设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }

    func normalized() -> String {
        var url = serverText.trimmingCharacters(in: .whitespaces)
        if !url.isEmpty && !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "http://" + url
        }
        return url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func save() {
        let url = normalized()
        TokenManager.serverURL = url
        toastMsg = "保存成功"
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run { presentationMode.wrappedValue.dismiss() }
        }
    }

    func clear() {
        TokenManager.serverURL = ""
        serverText = ""
        testResult = ""
        toastMsg = "已清空"
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run { toastMsg = nil }
        }
    }

    func testConnection() {
        UIApplication.shared.endEditing()
        let base = normalized()
        guard let u = URL(string: base + "/api/version/latest") else {
            testResult = "❌ 地址无效，请检查格式"; return
        }
        testing = true
        testResult = ""
        var req = URLRequest(url: u)
        req.httpMethod = "GET"
        req.timeoutInterval = 10
        Task {
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                let text = String(data: data, encoding: .utf8) ?? ""
                await MainActor.run {
                    testing = false
                    testResult = "✅ 连接成功 HTTP \(code)\n\(String(text.prefix(120)))"
                }
            } catch {
                let e = error as NSError
                await MainActor.run {
                    testing = false
                    testResult = "❌ 连接失败（错误码 \(e.code)）\n\(e.localizedDescription)\n目标地址：\(base)"
                }
            }
        }
    }
}
