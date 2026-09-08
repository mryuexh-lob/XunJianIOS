import SwiftUI
import AVFoundation
import CoreLocation
import Photos

// MARK: - 隐私政策弹窗（首次启动显示，对齐安卓版 LoginActivity.showPrivacyDialog）
struct PrivacyPolicyView: View {
    let onAgreed: () -> Void
    @State private var showFullPolicy = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 标题
                    Text("隐私政策与用户协议")
                        .font(.title3)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .center)

                    // 欢迎语
                    Text("欢迎使用电力巡检助手！")
                        .font(.subheadline)

                    // 权限说明（对齐安卓版文字）
                    Text("为了保障巡检业务的正常开展，我们需要获取以下权限：")
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 6) {
                        permissionRow("存储权限", "用于保存巡检照片与表单附件")
                        permissionRow("位置权限", "用于绑定巡检任务的地理位置")
                        permissionRow("相机权限", "用于现场拍照留档")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    // 隐私承诺
                    Text("我们不会收集您的通讯录等无关个人信息。请点击下方按钮表示同意。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 隐私政策链接
                    Button(action: { showFullPolicy = true }) {
                        Text("《隐私政策》")
                            .foregroundColor(.blue)
                            .font(.subheadline)
                            .underline()
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("不同意") {
                        exit(0) // 对齐安卓 finish() 行为
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        UserDefaults.standard.set(true, forKey: "privacyAgreed")
                        requestPermissions()
                        onAgreed()
                    } label: {
                        Text("同意并继续").bold()
                    }
                }
            }
            .alert("隐私政策详情", isPresented: $showFullPolicy) {
                Button("我知道了", role: .cancel) {}
            } message: {
                Text(privacyPolicyText())
            }
        }
        .navigationViewStyle(.stack)
    }

    private func permissionRow(_ name: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("·").foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).bold()
                Text(desc).foregroundColor(.secondary)
            }
        }
    }

    /// 请求运行时权限（相机、位置、相册）——对齐安卓 requestRuntimePermissions
    private func requestPermissions() {
        // 相机
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        // 位置
        CLLocationManager().requestWhenInUseAuthorization()
        // 相册（iOS 14+ 用新 API）
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }
        } else {
            PHPhotoLibrary.requestAuthorization { _ in }
        }
    }

    /// 隐私政策全文（简化版，对齐安卓 Toast 提示"隐私政策详情页"）
    private func privacyPolicyText() -> String {
        """
        电力巡检助手隐私政策

        一、我们收集的信息
        为提供巡检服务，我们需要获取以下权限：
        · 存储权限：保存巡检照片与表单附件
        · 位置权限：绑定巡检任务的地理位置
        · 相机权限：现场拍照留档

        二、信息使用
        收集的信息仅用于巡检业务，不会用于其他目的。

        三、信息安全
        我们采取合理措施保护您的信息安全，数据通过加密方式传输。

        四、权利
        您可以随时在系统设置中关闭上述权限。

        五、联系我们
        如有疑问，请联系应用管理员。
        """
    }
}
