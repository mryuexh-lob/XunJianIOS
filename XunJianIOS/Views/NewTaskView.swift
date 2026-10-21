import SwiftUI
import UIKit

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

    // 点位定位 + 现场照片（建单必填，任务才算建立完成）
    @StateObject private var locator = LocationFetcher()
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var photos: [String] = []
    @State private var thumbnails: [UIImage] = []
    /// 单一 sheet 承载拍照/相册，避免多个 .sheet 争抢导致"点相册先进相机"
    @State private var pickerSource: PhotoSource?
    @State private var showLocating = false

    let types = ["常规", "特巡", "夜巡", "故障"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("任务标题 *", text: $title)
                    TextField("地址", text: $address)
                    TextField("线路", text: $line)
                    TextField("杆塔", text: $tower)
                    TextField("点位", text: $point)
                    TextField("设备编号", text: $deviceNo)
                    Picker("任务类型", selection: $taskType) { ForEach(types, id: \.self) { Text($0) } }
                }

                Section(header: Text("点位定位")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("当前位置坐标").font(.subheadline)
                            Text(longitude.isEmpty ? "尚未获取定位"
                                 : String(format: "%.6f, %.6f", latitudeDouble, longitudeDouble))
                                .font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: getLocation) {
                            Label("获取当前位置", systemImage: "location.fill")
                                .font(.subheadline)
                        }
                        .disabled(showLocating)
                    }
                    if showLocating { ProgressView("定位中…").padding(.vertical, 4) }
                }

                Section(header: Text("现场照片（建单必传）")) {
                    PhotoPickerRows(onCamera: { openPicker(.camera) },
                                    onLibrary: { openPicker(.library) })
                    if !thumbnails.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(thumbnails.indices, id: \.self) { i in
                                    Image(uiImage: thumbnails[i])
                                        .resizable().scaledToFill()
                                        .frame(width: 72, height: 72).cornerRadius(8)
                                        .clipped()
                                }
                            }
                        }
                        .frame(height: 80)
                    }
                    Text("需至少上传 1 张现场照片，任务方可建立完成")
                        .font(.caption).foregroundColor(photos.isEmpty ? .red : .gray)
                }
            }
            .navigationTitle("新建检修任务")
            .navigationBarItems(leading: Button("取消") { presentationMode.wrappedValue.dismiss() },
                                trailing: Button("保存") { submit() })
            .alert(isPresented: $showError) {
                Alert(title: Text("提示"), message: Text(errorMsg ?? ""),
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
            .onReceive(locator.$coordinate) { coord in
                if let c = coord {
                    latitude = String(format: "%.6f", c.latitude)
                    longitude = String(format: "%.6f", c.longitude)
                    showLocating = false
                }
            }
            .onReceive(locator.$error) { err in
                if let err = err {
                    errorMsg = "定位失败：\(err)"; showError = true; showLocating = false
                }
            }
        }
    }

    private var latitudeDouble: Double { Double(latitude) ?? 0 }
    private var longitudeDouble: Double { Double(longitude) ?? 0 }

    func getLocation() {
        showLocating = true
        locator.fetch()
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
        guard !title.isEmpty else { errorMsg = "任务标题不能为空"; showError = true; return }
        guard !photos.isEmpty else { errorMsg = "请至少上传 1 张现场照片"; showError = true; return }
        busy = true
        Task {
            do {
                try await APIClient.shared.createInspection(
                    title: title, address: address, line: line, tower: tower,
                    point: point, deviceNo: deviceNo, taskType: taskType,
                    latitude: latitude, longitude: longitude,
                    photos: PhotoJSON.encode(photos))
                await MainActor.run { presentationMode.wrappedValue.dismiss(); onCreated() }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription; showError = true; busy = false }
            }
        }
    }
}
