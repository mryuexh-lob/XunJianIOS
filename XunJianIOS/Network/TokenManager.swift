import Foundation

/// 本地会话与配置管理。
/// Token 与服务器地址存放在 UserDefaults（与安卓端行为保持一致）。
struct TokenManager {
    private static let kToken  = "xj_token"
    private static let kUser   = "xj_username"
    private static let kRole   = "xj_role"
    private static let kServer = "xj_server"

    static var token: String? {
        get { UserDefaults.standard.string(forKey: kToken) }
        set { UserDefaults.standard.set(newValue, forKey: kToken) }
    }

    static var username: String? {
        get { UserDefaults.standard.string(forKey: kUser) }
        set { UserDefaults.standard.set(newValue, forKey: kUser) }
    }

    static var role: String? {
        get { UserDefaults.standard.string(forKey: kRole) }
        set { UserDefaults.standard.set(newValue, forKey: kRole) }
    }

    /// 服务器地址，默认不写死（空串），首次启动请在登录页填写实际后端地址。
    static var serverURL: String {
        get { UserDefaults.standard.string(forKey: kServer) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kServer) }
    }

    static func saveLogin(_ resp: LoginResponse) {
        token   = resp.token
        username = resp.username
        role   = resp.role
    }

    static func logout() {
        UserDefaults.standard.removeObject(forKey: kToken)
        UserDefaults.standard.removeObject(forKey: kUser)
        UserDefaults.standard.removeObject(forKey: kRole)
    }

    static var isLoggedIn: Bool { token != nil }
}
