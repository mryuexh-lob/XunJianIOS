import SwiftUI
import AVFoundation
import CoreLocation
import Photos

// MARK: - 隐私政策弹窗（首次启动显示，对齐安卓版 LoginActivity.showPrivacyDialog）
// 采用半透明遮罩 + 居中小卡片样式，避免全屏铺满显得生硬
struct PrivacyPolicyView: View {
    let onAgreed: () -> Void
    @State private var showFullPolicy = false

    var body: some View {
        ZStack {
            // 半透明遮罩（点击遮罩不关闭，必须明确选择）
            Color.black.opacity(0.45)
                .edgesIgnoringSafeArea(.all)

            // 居中卡片
            VStack(spacing: 0) {
                // 标题
                Text("隐私政策与用户协议")
                    .font(.headline)
                    .bold()
                    .padding(.top, 18)
                    .padding(.bottom, 10)

                // 可滚动内容
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("欢迎使用电力巡检助手！")
                            .font(.subheadline)

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

                        Text("我们不会收集您的通讯录等无关个人信息。请点击下方按钮表示同意。")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: { showFullPolicy = true }) {
                            Text("《隐私政策》")
                                .foregroundColor(.blue)
                                .font(.subheadline)
                                .underline()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 300)

                // 底部按钮
                HStack(spacing: 12) {
                    Button(action: { exit(0) }) {
                        Text("不同意")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray5))
                            .cornerRadius(10)
                    }

                    Button(action: {
                        UserDefaults.standard.set(true, forKey: "privacyAgreed")
                        requestPermissions()
                        onAgreed()
                    }) {
                        Text("同意并继续").bold()
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: 340)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 12)
            .padding(24)
        }
        .alert("隐私政策详情", isPresented: $showFullPolicy) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(privacyPolicyText())
        }
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
