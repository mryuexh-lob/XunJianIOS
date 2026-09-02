import SwiftUI
import Combine

/// 全局登录状态（驱动登录页与主界面的切换）。
class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = TokenManager.isLoggedIn

    func login()  { isLoggedIn = true }
    func logout() { TokenManager.logout(); isLoggedIn = false }
}

extension Color {
    /// 从十六进制构造颜色，如 Color(hex: 0x0a7d3f)。
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8)  & 0xFF) / 255.0,
            blue:  Double(hex        & 0xFF) / 255.0,
            opacity: alpha
        )
    }

    /// 国家电网风格主色（绿）。
    static let brand = Color(hex: 0x0a7d3f)
}
