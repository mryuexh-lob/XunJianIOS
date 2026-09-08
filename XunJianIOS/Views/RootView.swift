import SwiftUI

struct RootView: View {
    @StateObject private var appState = AppState()
    @State private var showPrivacyPolicy = !UserDefaults.standard.bool(forKey: "privacyAgreed")

    var body: some View {
        Group {
            if appState.isLoggedIn {
                MainTabView().environmentObject(appState)
            } else {
                LoginView().environmentObject(appState)
            }
        }
        .fullScreenCover(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView {
                // 用户同意后关闭隐私政策弹窗
                showPrivacyPolicy = false
            }
        }
    }
}
