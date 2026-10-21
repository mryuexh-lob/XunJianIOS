import Foundation
import UIKit
import CoreLocation
import SwiftUI

/// 从相机或相册选取照片（UIImagePickerController，iOS 2.0+，兼容 iOS 14）。
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImage: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ p: ImagePicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController,
                                  didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
            parent.presentationMode.wrappedValue.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
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
