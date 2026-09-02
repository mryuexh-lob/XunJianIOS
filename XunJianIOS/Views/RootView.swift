import SwiftUI

struct RootView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        Group {
            if appState.isLoggedIn {
                MainTabView().environmentObject(appState)
            } else {
                LoginView().environmentObject(appState)
            }
        }
    }
}
