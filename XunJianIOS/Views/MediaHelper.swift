import Foundation
import UIKit
import CoreLocation
import SwiftUI
import AVFoundation

/// 照片来源。
///
/// 说明：拍照/相册必须用**同一个 sheet 承载**（切换 source 而非新增第二个 .sheet）。
/// 同一视图上挂多个 `.sheet` 时 SwiftUI 只会让其中一个抢占展示，取消后才轮到下一个，
/// 表现就是"点从相册选择却先弹出相机、退出后才进相册"。
enum PhotoSource: Int, Identifiable {
    case camera = 0
    case library = 1

    var id: Int { rawValue }

    var uiSourceType: UIImagePickerController.SourceType {
        switch self {
        case .camera: return .camera
        case .library: return .photoLibrary
        }
    }
}

/// 从相机或相册选取照片（UIImagePickerController，iOS 2.0+，兼容 iOS 14）。
struct ImagePicker: UIViewControllerRepresentable {
    let source: PhotoSource
    /// 由调用方持有的展示状态；取消/完成时回写 false 以关闭 sheet。
    @Binding var isPresented: Bool
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        // 设备不支持该来源时（如模拟器无相机）回退相册，避免黑屏/崩溃
        if UIImagePickerController.isSourceTypeAvailable(source.uiSourceType) {
            picker.sourceType = source.uiSourceType
        } else {
            picker.sourceType = .photoLibrary
        }
        if picker.sourceType == .camera {
            picker.cameraCaptureMode = .photo
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePicker
        init(_ p: ImagePicker) { parent = p }

        func imagePickerController(_ picker: UIImagePickerController,
                                  didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            close(picker, image: info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            close(picker, image: nil)
        }

        /// 双层关闭：先让系统 picker 自身 dismiss，再在主线程把 isPresented 置 false。
        /// 只依赖 presentationMode 时，系统相机内置的「Cancel」按钮会点了没反应。
        private func close(_ picker: UIImagePickerController, image: UIImage?) {
            picker.dismiss(animated: true) {
                DispatchQueue.main.async {
                    if let image = image { self.parent.onImage(image) }
                    self.parent.isPresented = false
                }
            }
        }
    }
}

/// 相机权限：相机来源打开前必须确认已授权，否则 UIImagePickerController 打开就是黑屏。
enum PhotoPermission {
    static func ensureCamera(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    static let cameraDeniedTip = "未获得相机权限，请到「设置 → 隐私与安全性 → 相机」中允许「移动检修助手」使用相机"
    static let cameraUnavailableTip = "当前设备不支持拍照，请改用从相册选择"
}

/// 获取当前位置（CLLocationManager 单次定位，iOS 8+，兼容 iOS 14）。
final class LocationFetcher: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let manager = CLLocationManager()
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var error: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func fetch() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.first?.coordinate
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error.localizedDescription
    }
}

/// 把 UIImage 以 JPEG 存入 App 私有 Documents 目录，返回文件路径引用（不上传后端二进制）。
enum ImageStore {
    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let name = "\(UUID().uuidString).jpg"
        let url = dir.appendingPathComponent(name)
        do { try data.write(to: url); return url.path } catch { return nil }
    }
}

/// 把照片路径数组序列化成 JSON 字符串（与安卓端格式一致）。
enum PhotoJSON {
    static func encode(_ paths: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: paths) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
    static func decode(_ json: String?) -> [String] {
        guard let json = json, !json.isEmpty,
              let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else { return [] }
        return arr
    }
}

/// 照片采集行（拍照 / 从相册选择）。
///
/// 关键点：两个操作必须是**各自独立的一行** Button，并加 `.buttonStyle(BorderlessButtonStyle())`。
/// Form 的同一行内放多个 Button 时，整行会被当作一个可点区域、只命中第一个按钮，
/// 这就是"点从相册选择却触发了拍照"的成因。
struct PhotoPickerRows: View {
    let onCamera: () -> Void
    let onLibrary: () -> Void

    var body: some View {
        Group {
            Button(action: onCamera) {
                HStack {
                    Label("拍照", systemImage: "camera").font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                }
            }
            .buttonStyle(BorderlessButtonStyle())

            Button(action: onLibrary) {
                HStack {
                    Label("从相册选择", systemImage: "photo.on.rectangle").font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
}
