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
