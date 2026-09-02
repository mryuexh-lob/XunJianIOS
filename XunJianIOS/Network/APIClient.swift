import Foundation

struct APIResponse {
    let statusCode: Int
    let body: String
}

enum APIError: LocalizedError {
    case invalidURL
    case http(Int, String)
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "服务器地址无效"
        case .http(_, let msg):      return msg
        case .decode(let m):         return m
        }
    }
}

/// 后端 REST 客户端（原生 URLSession + async/await，无任何第三方依赖）。
/// 鉴权头与安卓端一致：Authorization: <token>
struct APIClient {
    static let shared = APIClient()
    private let decoder = JSONDecoder()

    // MARK: - 底层请求
    private func request(method: String,
                         path: String,
                         token: String? = nil,
                         body: Data? = nil) async throws -> APIResponse {
        let base = TokenManager.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if let token = token { req.setValue(token, forHTTPHeaderField: "Authorization") }
        req.httpBody = body
        req.timeoutInterval = 15
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let text = String(data: data, encoding: .utf8) ?? ""
        return APIResponse(statusCode: code, body: text)
    }

    private func extractMessage(_ body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let msg = obj["message"] as? String else { return nil }
        return msg
    }

    private func json(_ dict: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: dict)
    }

    // MARK: - 鉴权
    func login(username: String, password: String) async throws -> LoginResponse {
        let data = try json(["username": username, "password": password])
        let r = try await request(method: "POST", path: "/api/auth/login", body: data)
        guard r.statusCode == 200 else {
            throw APIError.http(r.statusCode, extractMessage(r.body) ?? "登录失败（HTTP \(r.statusCode)）")
        }
        return try decoder.decode(LoginResponse.self, from: Data(r.body.utf8))
    }

    func me() async throws -> UserInfo {
        let r = try await request(method: "GET", path: "/api/auth/me", token: TokenManager.token)
        guard r.statusCode == 200 else {
            throw APIError.http(r.statusCode, extractMessage(r.body) ?? "获取用户信息失败")
        }
        return try decoder.decode(UserInfo.self, from: Data(r.body.utf8))
    }

    /// 修改个人密码（保留 N1 弱口令缺陷：服务端不校验复杂度）
    func changePassword(old: String, new: String) async throws {
        let data = try json(["oldPassword": old, "newPassword": new])
        let r = try await request(method: "PUT", path: "/api/auth/me/password",
                                  token: TokenManager.token, body: data)
        guard r.statusCode == 200 else {
            throw APIError.http(r.statusCode, extractMessage(r.body) ?? "修改密码失败")
        }
    }

    // MARK: - 巡检任务
    func inspections(status: String?, keyword: String?, taskType: String?) async throws -> [InspectionTask] {
        var comps = URLComponents(string: "/api/inspections")!
        var q: [URLQueryItem] = []
        if let s = status,  !s.isEmpty { q.append(URLQueryItem(name: "status",    value: s)) }
        if let t = taskType, !t.isEmpty { q.append(URLQueryItem(name: "taskType",  value: t)) }
        if let k = keyword,  !k.isEmpty { q.append(URLQueryItem(name: "keyword",   value: k)) }
        comps.queryItems = q.isEmpty ? nil : q
        let path = comps.string ?? "/api/inspections"
        let r = try await request(method: "GET", path: path, token: TokenManager.token)
        guard r.statusCode == 200 else {
            throw APIError.http(r.statusCode, extractMessage(r.body) ?? "获取任务列表失败")
        }
        return try decoder.decode([InspectionTask].self, from: Data(r.body.utf8))
    }

    func createInspection(_ fields: [String: String]) async throws {
        let data = try json(fields)
        let r = try await request(method: "POST", path: "/api/inspections",
                                  token: TokenManager.token, body: data)
        guard r.statusCode == 200 else {
            throw APIError.http(r.statusCode, extractMessage(r.body) ?? "创建任务失败")
        }
    }

    func inspectionDetail(id: Int) async throws -> InspectionTask {
        let r = try await request(method: "GET", path: "/api/inspections/\(id)", token: TokenManager.token)
        guard r.statusCode == 200 else {
            throw APIError.http(r.statusCode, extractMessage(r.body) ?? "获取任务详情失败")
        }
        return try decoder.decode(InspectionTask.self, from: Data(r.body.utf8))
    }

    func acceptInspection(id: Int) async throws {
        let r = try await request(method: "POST", path: "/api/inspections/\(id)/accept", token: TokenManager.token)
        guard r.statusCode == 200 else { throw APIError.http(r.statusCode, extractMessage(r.body) ?? "接单失败") }
    }

    func assignInspection(id: Int, assignee: String) async throws {
        let data = try json(["assignee": assignee])
        let r = try await request(method: "POST", path: "/api/inspections/\(id)/assign",
                                  token: TokenManager.token, body: data)
        guard r.statusCode == 200 else { throw APIError.http(r.statusCode, extractMessage(r.body) ?? "指派失败") }
    }

    func hazardInspection(id: Int, point: String, level: String, desc: String, duty: Bool) async throws {
        let data = try json(["point": point, "level": level, "desc": desc, "duty": duty])
        let r = try await request(method: "POST", path: "/api/inspections/\(id)/hazard",
                                  token: TokenManager.token, body: data)
        guard r.statusCode == 200 else { throw APIError.http(r.statusCode, extractMessage(r.body) ?? "危险点登记失败") }
    }

    func formInspection(id: Int, items: String, deviceNo: String) async throws {
        let data = try json(["items": items, "deviceNo": deviceNo])
        let r = try await request(method: "POST", path: "/api/inspections/\(id)/form",
                                  token: TokenManager.token, body: data)
        guard r.statusCode == 200 else { throw APIError.http(r.statusCode, extractMessage(r.body) ?? "表单提交失败") }
    }

    func updateInspection(id: Int, fields: [String: String]) async throws {
        let data = try json(fields)
        let r = try await request(method: "PUT", path: "/api/inspections/\(id)",
                                 token: TokenManager.token, body: data)
        guard r.statusCode == 200 else { throw APIError.http(r.statusCode, extractMessage(r.body) ?? "更新失败") }
    }

    func deleteInspection(id: Int) async throws {
        let r = try await request(method: "DELETE", path: "/api/inspections/\(id)", token: TokenManager.token)
        guard r.statusCode == 200 else { throw APIError.http(r.statusCode, extractMessage(r.body) ?? "删除失败") }
    }

    func inspectors() async throws -> [Inspector] {
        let r = try await request(method: "GET", path: "/api/inspections/inspectors", token: TokenManager.token)
        guard r.statusCode == 200 else { throw APIError.http(r.statusCode, extractMessage(r.body) ?? "获取人员失败") }
        return try decoder.decode([Inspector].self, from: Data(r.body.utf8))
    }

    // MARK: - 版本检查（匿名接口）
    func checkUpdate() async throws -> AppVersion? {
        let r = try await request(method: "GET", path: "/api/version/latest")
        guard r.statusCode == 200 else { throw APIError.http(r.statusCode, "获取版本失败") }
        if let obj = try? JSONSerialization.jsonObject(with: Data(r.body.utf8)) as? [String: Any],
           obj["message"] != nil { return nil }
        return try? decoder.decode(AppVersion.self, from: Data(r.body.utf8))
    }
}
