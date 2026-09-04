import SwiftUI

struct NewTaskView: View {
    let onCreated: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var address = ""
    @State private var line = ""
    @State private var tower = ""
    @State private var point = ""
    @State private var deviceNo = ""
    @State private var taskType = "常规"
    @State private var errorMsg: String?
    @State private var showError = false
    @State private var busy = false
    let types = ["常规", "特巡", "夜巡", "故障"]

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("任务标题 *", text: $title)
                    TextField("地址", text: $address)
                    TextField("线路", text: $line)
                    TextField("杆塔", text: $tower)
                    TextField("点位", text: $point)
                    TextField("设备编号", text: $deviceNo)
                    Picker("任务类型", selection: $taskType) { ForEach(types, id: \.self) { Text($0) } }
                }
            }
            .navigationTitle("新建巡检任务")
            .navigationBarItems(leading: Button("取消") { presentationMode.wrappedValue.dismiss() },
                                trailing: Button("保存") { submit() })
            .alert(isPresented: $showError) {
                Alert(title: Text("提示"), message: Text(errorMsg ?? ""),
                      dismissButton: .default(Text("确定")))
            }
        }
    }
    func submit() {
        guard !title.isEmpty else { errorMsg = "任务标题不能为空"; showError = true; return }
        busy = true
        Task {
            do {
                let fields: [String: String] = [
                    "title": title, "address": address, "line": line,
                    "tower": tower, "point": point, "deviceNo": deviceNo, "taskType": taskType
                ]
                try await APIClient.shared.createInspection(fields)
                await MainActor.run { presentationMode.wrappedValue.dismiss(); onCreated() }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription; showError = true; busy = false }
            }
        }
    }
}
