import SwiftUI

struct TaskDetailView: View {
    let taskId: Int
    @Environment(\.dismiss) var dismiss
    @State private var task: InspectionTask?
    @State private var busy = false
    @State private var message: String?
    @State private var showError = false
    @State private var showHazard = false
    @State private var showForm = false
    @State private var showAssign = false
    @State private var showUpdate = false
    @State private var inspectors: [Inspector] = []

    var body: some View {
        Group {
            if busy && task == nil {
                ProgressView()
            } else if let task = task {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(task.title ?? "任务").font(.title3).bold()
                            Spacer()
                            StatusBadge(status: task.status)
                        }
                        infoRow("任务单号", task.taskNo)
                        infoRow("状态", task.status)
                        infoRow("接单状态", task.acceptStatus)
                        infoRow("地址", task.address)
                        infoRow("线路", task.line)
                        infoRow("杆塔", task.tower)
                        infoRow("点位", task.point)
                        infoRow("设备编号", task.deviceNo)
                        infoRow("任务类型", task.taskType)
                        infoRow("指派给", task.assignee)
                        infoRow("作业时间", task.workTime)
                        infoRow("创建时间", task.createdAt)
                        if let remark = task.remark, !remark.isEmpty { infoRow("备注", remark) }

                        Divider()
                        Text("操作").font(.headline)

                        actionButton("接单", icon: "checkmark.circle") {
                            try await APIClient.shared.acceptInspection(id: taskId)
                        }
                        actionButton("更新状态/备注", icon: "pencil") { showUpdate = true }
                        actionButton("危险点登记", icon: "exclamationmark.triangle") { showHazard = true }
                        actionButton("表单化作业", icon: "list.bullet") { showForm = true }
                        actionButton("指派", icon: "person.2") {
                            await loadInspectors()
                            showAssign = true
                        }

                        Button(role: .destructive) {
                            Task {
                                busy = true
                                do {
                                    try await APIClient.shared.deleteInspection(id: taskId)
                                    await MainActor.run { dismiss() }
                                } catch {
                                    message = error.localizedDescription; showError = true
                                }
                                busy = false
                            }
                        } label: {
                            Label("删除任务", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            } else {
                Text("加载失败").foregroundColor(.gray)
            }
        }
        .navigationTitle("任务详情")
        .onAppear { Task { await load() } }
        .alert(isPresented: $showError) {
            Alert(title: Text("提示"), message: Text(message ?? ""),
                  dismissButton: .default(Text("确定")) { Task { await load() } })
        }
        .sheet(isPresented: $showHazard)  { HazardSheet(taskId: taskId, onDone: reload) }
        .sheet(isPresented: $showForm)    { FormSheet(taskId: taskId, deviceNo: task?.deviceNo ?? "", onDone: reload) }
        .sheet(isPresented: $showAssign)  { AssignSheet(taskId: taskId, inspectors: inspectors, onDone: reload) }
        .sheet(isPresented: $showUpdate)  { UpdateSheet(taskId: taskId, currentStatus: task?.status, onDone: reload) }
    }

    func load() async {
        busy = true
        do { task = try await APIClient.shared.inspectionDetail(id: taskId) }
        catch { message = error.localizedDescription; showError = true }
        busy = false
    }
    func reload() { Task { await load() } }
    func loadInspectors() async {
        do { inspectors = try await APIClient.shared.inspectors() } catch { }
    }
    func infoRow(_ k: String, _ v: String?) -> some View {
        HStack(alignment: .top) {
            Text(k).foregroundColor(.gray).frame(width: 80, alignment: .leading)
            Text(v ?? "-").fixedSize(horizontal: false, vertical: true)
            Spacer()
        }.font(.subheadline)
    }
    func actionButton(_ title: String, icon: String, action: @escaping () async throws -> Void) -> some View {
        Button {
            Task {
                busy = true
                do { try await action(); await load() }
                catch { message = error.localizedDescription; showError = true }
                busy = false
            }
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

// MARK: - 危险点登记
struct HazardSheet: View {
    let taskId: Int
    let onDone: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var point = ""
    @State private var level = "一般"
    @State private var desc = ""
    @State private var duty = false
    @State private var errorMsg: String?
    @State private var showError = false
    let levels = ["一般", "较大", "重大"]

    var body: some View {
        NavigationView {
            Form {
                TextField("危险点", text: $point)
                Picker("等级", selection: $level) { ForEach(levels, id: \.self) { Text($0) } }
                Toggle("需值守", isOn: $duty)
                TextField("描述", text: $desc)
            }
            .navigationTitle("危险点登记")
            .navigationBarItems(leading: Button("取消") { dismiss() },
                                trailing: Button("提交") { submit() })
            .alert(isPresented: $showError) {
                Alert(title: Text("错误"), message: Text(errorMsg ?? ""),
                      dismissButton: .default(Text("确定")))
            }
        }
    }
    func submit() {
        Task {
            do {
                try await APIClient.shared.hazardInspection(id: taskId, point: point,
                                                            level: level, desc: desc, duty: duty)
                await MainActor.run { dismiss(); onDone() }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription; showError = true }
            }
        }
    }
}

// MARK: - 表单化作业
struct FormSheet: View {
    let taskId: Int
    let deviceNo: String
    let onDone: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var items = ""
    @State private var dev: String
    @State private var errorMsg: String?
    @State private var showError = false

    init(taskId: Int, deviceNo: String, onDone: @escaping () -> Void) {
        self.taskId = taskId; self.deviceNo = deviceNo; self.onDone = onDone
        _dev = State(initialValue: deviceNo)
    }
    var body: some View {
        NavigationView {
            Form {
                TextField("设备编号", text: $dev)
                TextField("巡检项（JSON 数组，如 [\"测温\",\"紧固\"]）", text: $items)
            }
            .navigationTitle("表单化作业")
            .navigationBarItems(leading: Button("取消") { dismiss() },
                                trailing: Button("提交") { submit() })
            .alert(isPresented: $showError) {
                Alert(title: Text("错误"), message: Text(errorMsg ?? ""),
                      dismissButton: .default(Text("确定")))
            }
        }
    }
    func submit() {
        Task {
            do {
                try await APIClient.shared.formInspection(id: taskId, items: items, deviceNo: dev)
                await MainActor.run { dismiss(); onDone() }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription; showError = true }
            }
        }
    }
}

// MARK: - 指派
struct AssignSheet: View {
    let taskId: Int
    let inspectors: [Inspector]
    let onDone: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selected = ""
    @State private var errorMsg: String?
    @State private var showError = false

    var body: some View {
        NavigationView {
            Form {
                Picker("指派人", selection: $selected) {
                    Text("请选择").tag("")
                    ForEach(inspectors) { ins in
                        Text(ins.realName ?? ins.username ?? "\(ins.id)").tag(ins.username ?? "")
                    }
                }
            }
            .navigationTitle("指派任务")
            .navigationBarItems(leading: Button("取消") { dismiss() },
                                trailing: Button("确定") { submit() })
            .alert(isPresented: $showError) {
                Alert(title: Text("错误"), message: Text(errorMsg ?? ""),
                      dismissButton: .default(Text("确定")))
            }
        }
    }
    func submit() {
        guard !selected.isEmpty else { errorMsg = "请选择指派人"; showError = true; return }
        Task {
            do {
                try await APIClient.shared.assignInspection(id: taskId, assignee: selected)
                await MainActor.run { dismiss(); onDone() }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription; showError = true }
            }
        }
    }
}

// MARK: - 更新状态/备注
struct UpdateSheet: View {
    let taskId: Int
    let currentStatus: String?
    let onDone: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var status: String
    @State private var remark = ""
    @State private var errorMsg: String?
    @State private var showError = false
    let statuses = ["待执行", "执行中", "已完成"]

    init(taskId: Int, currentStatus: String?, onDone: @escaping () -> Void) {
        self.taskId = taskId; self.currentStatus = currentStatus; self.onDone = onDone
        _status = State(initialValue: currentStatus ?? "待执行")
    }
    var body: some View {
        NavigationView {
            Form {
                Picker("状态", selection: $status) { ForEach(statuses, id: \.self) { Text($0) } }
                TextField("备注", text: $remark)
            }
            .navigationTitle("更新任务")
            .navigationBarItems(leading: Button("取消") { dismiss() },
                                trailing: Button("确定") { submit() })
            .alert(isPresented: $showError) {
                Alert(title: Text("错误"), message: Text(errorMsg ?? ""),
                      dismissButton: .default(Text("确定")))
            }
        }
    }
    func submit() {
        Task {
            do {
                var fields: [String: String] = [:]
                if !status.isEmpty { fields["status"] = status }
                if !remark.isEmpty { fields["remark"] = remark }
                try await APIClient.shared.updateInspection(id: taskId, fields: fields)
                await MainActor.run { dismiss(); onDone() }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription; showError = true }
            }
        }
    }
}
