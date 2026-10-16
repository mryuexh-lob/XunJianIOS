import Foundation

// MARK: - 登录响应
struct LoginResponse: Codable {
    let token: String
    let userId: Int?
    let username: String?
    let role: String?
    let menus: [MenuInfo]?
}

struct MenuInfo: Codable {
    let name: String?
    let path: String?
    let icon: String?
    let parentId: Int?
}

// MARK: - 当前用户信息（个人中心）
struct UserInfo: Codable {
    let userId: Int?
    let username: String?
    let role: String?
    let realName: String?
    let phone: String?
    let email: String?
    let menus: [MenuInfo]?
}

// MARK: - 巡检任务
struct InspectionTask: Identifiable, Codable {
    let id: Int
    let userId: Int?
    let title: String?
    let address: String?
    let status: String?
    let createdAt: String?
    let remark: String?
    let taskNo: String?
    let line: String?
    let tower: String?
    let point: String?
    let deviceNo: String?
    let taskType: String?
    let assignee: String?
    let acceptStatus: String?
    let workTime: String?
    let formResult: String?
    let hazard: String?
    // 点位定位与现场照片（建单采集）
    let longitude: String?
    let latitude: String?
    let photos: String?
    // 任务归属人（ADMIN 查看全量任务时展示）
    let owner: String?
    let ownerName: String?
}

// MARK: - 表单化作业结果（formResult 的 JSON 子串解析）
struct FormResult {
    let items: [String]
    let deviceNo: String?
    let workTime: String?
    let content: String?
    let photos: [String]

    static func parse(_ json: String) -> FormResult? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let itemsRaw = obj["items"] as? String ?? "[]"
        let items = (try? JSONSerialization.jsonObject(with: Data(itemsRaw.utf8)) as? [String]) ?? []
        let photosRaw = obj["photos"] as? String ?? "[]"
        let photos = (try? JSONSerialization.jsonObject(with: Data(photosRaw.utf8)) as? [String]) ?? []
        return FormResult(items: items,
                          deviceNo: obj["deviceNo"] as? String,
                          workTime: obj["workTime"] as? String,
                          content: obj["content"] as? String,
                          photos: photos)
    }
}

// MARK: - 操作日志
struct OpLog: Identifiable, Codable {
    let id: Int
    let logType: String?
    let level: String?
    let username: String?
    let action: String?
    let detail: String?
    let ip: String?
    let createTime: String?
}

struct LogStats: Codable {
    let business: Int?
    let system: Int?
    let total: Int?
}

struct LogListResponse: Codable {
    let list: [OpLog]?
    let stats: LogStats?
}

// MARK: - 后台管理（用户 / 角色权限）
struct AdminUser: Identifiable, Codable {
    let id: Int
    let username: String?
    let realName: String?
    let role: String?
    let phone: String?
    let email: String?
}

struct RoleInfo: Identifiable, Codable {
    let id: Int
    let code: String?
    let name: String?
    let remark: String?
    let menus: String?
}

// MARK: - App 版本
struct AppVersion: Codable {
    let id: Int?
    let versionCode: Int?
    let versionName: String?
    let updateContent: String?
    let forceUpdate: Bool?
    let downloadUrl: String?
    let active: Bool?
    let createTime: String?
    let publishTime: String?
}

// MARK: - 可指派人员
struct Inspector: Identifiable, Codable {
    let id: Int
    let username: String?
    let realName: String?
    let role: String?
}
