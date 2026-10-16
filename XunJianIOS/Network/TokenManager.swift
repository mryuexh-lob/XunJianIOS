import Foundation

/// 本地会话与配置管理。
/// Token 与服务器地址存放在 UserDefaults（与安卓端行为保持一致）。
struct TokenManager {
    private static let kToken  = "xj_token"
    private static let kUser   = "xj_username"
    private static let kRole   = "xj_role"
    private static let kServer = "xj_server"
    private static let kMenus  = "xj_menus"

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

    /// 角色菜单权限（由后台 /api/auth/login 与 /api/auth/me 返回，逗号分隔 path）。
    /// 用于让"后台权限配置在 App 生效"：不同角色登录后可见功能不同。
    static var menus: String {
        get { UserDefaults.standard.string(forKey: kMenus) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kMenus) }
    }

    /// 服务器地址，默认不写死（空串），首次启动请在登录页填写实际后端地址。
    static var serverURL: String {
        get { UserDefaults.standard.string(forKey: kServer) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kServer) }
    }

    static func saveMenuPaths(_ list: [MenuInfo]?) {
        let paths = (list ?? []).compactMap { $0.path }.filter { !$0.isEmpty }
        menus = paths.joined(separator: ",")
    }

    static func saveLogin(_ resp: LoginResponse) {
        token   = resp.token
        username = resp.username
        role   = resp.role
        saveMenuPaths(resp.menus)
    }

    /// 是否拥有某菜单 path 的权限（后台下发优先；为空时按内置角色回退，避免入口全部隐藏）。
    static func canAccess(_ path: String) -> Bool {
        let m = menus
        if !m.isEmpty {
            return m.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .contains(path)
        }
        switch role {
        case "ADMIN":   return true
        case "AUDITOR": return path == "/system/log"
        default:        return path.hasPrefix("/inspection")
        }
    }

    static func logout() {
        UserDefaults.standard.removeObject(forKey: kToken)
        UserDefaults.standard.removeObject(forKey: kUser)
        UserDefaults.standard.removeObject(forKey: kRole)
        UserDefaults.standard.removeObject(forKey: kMenus)
    }

    static var isLoggedIn: Bool { token != nil }
}
