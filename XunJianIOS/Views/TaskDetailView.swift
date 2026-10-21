import SwiftUI
import UIKit

/// 任务详情页的操作弹窗。
///
/// 同一视图上叠多个 `.sheet(isPresented:)` 时 SwiftUI 只会让其中一个抢占展示，
/// 导致点 A 却弹出 B（或点了没反应），因此统一收敛为一个枚举 + 单个 `.sheet(item:)`。
enum TaskDetailSheet: String, Identifiable {
    case hazard, form, assign, update
    var id: String { rawValue }
}

struct TaskDetailView: View {
    let taskId: Int
    @Environment(\.presentationMode) var presentationMode
    @State private var task: InspectionTask?
    @State private var busy = false
    @State private var message: String?
    @State private var showError = false
    @State private var activeSheet: TaskDetailSheet?
    @State private var inspectors: [Inspector] = []

    /// AUDITOR 无 /inspection/task 权限，仅可查看，不可操作。
    private var canManage: Bool { TokenManager.canAccess("/inspection/task") }

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
                        // ADMIN 查看全量任务时，展示任务归属人
                        if let owner = task.owner, owner != "—" {
                            infoRow("归属人", (task.ownerName ?? owner).isEmpty ? owner : (task.ownerName ?? owner))
                        }

                        Divider()
                        Text("点位定位").font(.headline)
                        infoRow("经纬度", coordText(task))

                        Divider()
                        Text("现场照片").font(.headline)
                        PhotoThumbRow(paths: PhotoJSON.decode(task.photos))

                        // 表单化作业结果（处理内容 + 处理照片）
                        if let form = task.formResult, !form.isEmpty,
                           let model = FormResult.parse(form) {
                            Divider()
                            Text("作业结果").font(.headline)
                            infoRow("处理内容", model.content)
                            infoRow("作业设备", model.deviceNo)
                            infoRow("作业时间", model.workTime)
                            if !model.items.isEmpty {
                                infoRow("巡检项", model.items.joined(separator: "、"))
                            }
                            if !model.photos.isEmpty {
                                PhotoThumbRow(paths: model.photos)
                            }
                        }

                        if canManage {
                            Divider()
                            Text("操作").font(.headline)
                            actionButton("接单", icon: "checkmark.circle") {
                                try await APIClient.shared.acceptInspection(id: taskId)
                            }
                            actionButton("更新状态/备注", icon: "pencil") { self.activeSheet = .update }
                            actionButton("危险点登记", icon: "exclamationmark.triangle") { self.activeSheet = .hazard }
                            actionButton("表单化作业", icon: "list.bullet") { self.activeSheet = .form }
                            actionButton("指派", icon: "person.2") {
                                await self.loadInspectors()
                                self.activeSheet = .assign
                            }
                            Button {
                                Task {
                                    busy = true
                                    do {
                                        try await APIClient.shared.deleteInspection(id: taskId)
                                        await MainActor.run { presentationMode.wrappedValue.dismiss() }
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
        .sheet(item: $activeSheet) { kind in
            switch kind {
            case .hazard:
                HazardSheet(taskId: taskId, onDone: reload)
            case .form:
                FormSheet(taskId: taskId, deviceNo: task?.deviceNo ?? "", onDone: reload)
            case .assign:
                AssignSheet(taskId: taskId, inspectors: inspectors, onDone: reload)
            case .update:
                UpdateSheet(taskId: taskId, currentStatus: task?.status, onDone: reload)
            }
        }
    }

    private func coordText(_ t: InspectionTask) -> String? {
        guard let lat = t.latitude, !lat.isEmpty, let lng = t.longitude, !lng.isEmpty else { return nil }
        return "\(lat), \(lng)"
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

/// 现场/作业照片缩略图（按 app 私有路径读取，不上传后端二进制）。
struct PhotoThumbRow: View {
    let paths: [String]
    var body: some View {
        if paths.isEmpty {
            Text("无").font(.subheadline).foregroundColor(.gray)
        } else {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(paths.indices, id: \.self) { i in
                        if let img = UIImage(contentsOfFile: paths[i]) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 96, height: 96).cornerRadius(8).clipped()
                        } else {
                            Image(systemName: "photo")
                                .frame(width: 96, height: 96)
                                .background(Color(.systemGray6)).cornerRadius(8)
                        }
                    }
                }
            }
            .frame(height: 104)
        }
    }
}

// MARK: - 危险点登记
struct HazardSheet: View {
    let taskId: Int
    let onDone: () -> Void
    @Environment(\.presentationMode) var presentationMode
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
            .navigationBarItems(leading: Button("取消") { presentationMode.wrappedValue.dismiss() },
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
                await MainActor.run { presentationMode.wrappedValue.dismiss(); onDone() }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription; showError = true }
            }
        }
    }
}

// MARK: - 表单化作业（含处理内容 + 处理照片）
struct FormSheet: View {
    let taskId: Int
    let deviceNo: String
    let onDone: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var items = ""
    @State private var dev: String
    @State private var content = ""
    @State private var photos: [String] = []
    @State private var thumbnails: [UIImage] = []
    /// 单一 sheet 承载拍照/相册，避免多个 .sheet 争抢导致"点相册先进相机"
    @State private var pickerSource: PhotoSource?
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
                Section(header: Text("处理内容")) {
                    TextEditor(text: $content)
                        .frame(minHeight: 100)
                }
                Section(header: Text("处理照片")) {
                    PhotoPickerRows(onCamera: { openPicker(.camera) },
                                    onLibrary: { openPicker(.library) })
                    if !thumbnails.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(thumbnails.indices, id: \.self) { i in
                                    Image(uiImage: thumbnails[i])
                                        .resizable().scaledToFill()
                                        .frame(width: 72, height: 72).cornerRadius(8).clipped()
                                }
                            }
                        }
                        .frame(height: 80)
                    }
                }
            }
            .navigationTitle("表单化作业")
            .navigationBarItems(leading: Button("取消") { presentationMode.wrappedValue.dismiss() },
                                trailing: Button("提交") { submit() })
            .alert(isPresented: $showError) {
                Alert(title: Text("错误"), message: Text(errorMsg ?? ""),
                      dismissButton: .default(Text("确定")))
            }
            .sheet(item: $pickerSource) { src in
                ImagePicker(source: src,
                            isPresented: Binding(
                                get: { pickerSource != nil },
                                set: { if !$0 { pickerSource = nil } })) { img in
                    handlePicked(img)
                }
            }
        }
    }
    /// 打开拍照/相册：拍照先确认相机权限与设备可用性，再统一走同一个 sheet。
    func openPicker(_ src: PhotoSource) {
        if src == .camera {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                errorMsg = PhotoPermission.cameraUnavailableTip; showError = true; return
            }
            PhotoPermission.ensureCamera { granted in
                if granted {
                    pickerSource = .camera
                } else {
                    errorMsg = PhotoPermission.cameraDeniedTip; showError = true
                }
            }
        } else {
            pickerSource = .library
        }
    }
    func handlePicked(_ image: UIImage) {
        guard let path = ImageStore.save(image) else {
            errorMsg = "照片保存失败"; showError = true; return
        }
        photos.append(path)
        thumbnails.append(image)
    }
    func submit() {
        Task {
            do {
                try await APIClient.shared.formInspection(id: taskId, items: items, deviceNo: dev,
                                                         content: content,
                                                         photos: PhotoJSON.encode(photos))
                await MainActor.run { presentationMode.wrappedValue.dismiss(); onDone() }
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
    @Environment(\.presentationMode) var presentationMode
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
            .navigationBarItems(leading: Button("取消") { presentationMode.wrappedValue.dismiss() },
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
                await MainActor.run { presentationMode.wrappedValue.dismiss(); onDone() }
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
    @Environment(\.presentationMode) var presentationMode
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
            .navigationBarItems(leading: Button("取消") { presentationMode.wrappedValue.dismiss() },
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
                await MainActor.run { presentationMode.wrappedValue.dismiss(); onDone() }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription; showError = true }
            }
        }
    }
}
