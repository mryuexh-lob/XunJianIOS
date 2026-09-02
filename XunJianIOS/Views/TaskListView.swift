import SwiftUI

struct StatusBadge: View {
    let status: String?
    var body: some View {
        let s = status ?? ""
        let color: Color = s == "已完成" ? .green : (s == "执行中" ? .orange : .gray)
        return Text(s)
            .font(.caption2)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

struct TaskListView: View {
    @State private var tasks: [InspectionTask] = []
    @State private var statusFilter = ""
    @State private var keyword = ""
    @State private var taskType = ""
    @State private var busy = false
    @State private var errorMsg: String?
    @State private var showNew = false
    @State private var showFilter = false

    let statuses = ["", "待执行", "执行中", "已完成"]

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("搜索标题", text: $keyword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("筛选") { showFilter.toggle() }
                }
                .padding(.horizontal, 12).padding(.top, 8)

                if showFilter {
                    VStack(spacing: 8) {
                        Picker("状态", selection: $statusFilter) {
                            ForEach(statuses, id: \.self) { Text($0.isEmpty ? "全部" : $0) }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        TextField("任务类型", text: $taskType)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("应用筛选") { Task { await load() } }
                    }
                    .padding(.horizontal, 12)
                }

                if busy && tasks.isEmpty {
                    ProgressView()
                } else if tasks.isEmpty {
                    Spacer()
                    Text("暂无巡检任务").foregroundColor(.gray)
                    Spacer()
                } else {
                    List(tasks) { task in
                        NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title ?? "未命名任务").font(.headline)
                                HStack {
                                    Text(task.taskNo ?? "").font(.caption).foregroundColor(.gray)
                                    Spacer()
                                    StatusBadge(status: task.status)
                                }
                                if let addr = task.address, !addr.isEmpty {
                                    Text(addr).font(.caption).foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("巡检任务")
            .navigationBarItems(trailing: Button(action: { showNew = true }) {
                Image(systemName: "plus")
            })
            .onAppear { Task { await load() } }
            .sheet(isPresented: $showNew) {
                NewTaskView(onCreated: { Task { await load() } })
            }
        }
        .navigationViewStyle(.stack)
    }

    func load() async {
        busy = true; errorMsg = nil
        do {
            tasks = try await APIClient.shared.inspections(status: statusFilter,
                                                          keyword: keyword,
                                                          taskType: taskType)
        } catch {
            errorMsg = error.localizedDescription
        }
        busy = false
    }
}
