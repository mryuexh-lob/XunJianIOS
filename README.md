# 电力巡检助手 · iOS 客户端（XunJianIOS）

与安卓端（XunJianApp）共用同一套后端，功能对齐：登录、巡检任务列表/新建/详情、接单、指派、危险点登记、表单化作业、个人中心、修改密码、关于与版本检查。

> ⚠️ 重要：当前 Windows 环境**无法编译 iOS 安装包**（苹果工具链 `xcodebuild` 只能在 macOS 运行）。
> 本目录提供的是**完整、可直接在 Mac 上编译出 `.ipa` 的 Xcode 工程源码**，配合云构建配置（GitHub Actions）即可自动出包。
> 真正的打包动作需要在 Mac 或 macOS 云构建（本仓库已配 `build-ipa.yml`）上完成。

---

## 一、目录结构

```
iOS/XunJianIOS/
├── XunJianIOS/                 # 源码（SwiftUI）
│   ├── App/                    # @main 入口、AppState、Color 扩展
│   ├── Models/                 # 数据模型（与后端 JSON 字段对齐）
│   ├── Network/                # TokenManager + APIClient（URLSession）
│   ├── Views/                  # 各页面
│   └── Assets.xcassets/        # 资源目录（AppIcon 可后续补图）
├── Info.plist                  # 应用配置（已允许 HTTP 明文，等同安卓）
├── project.yml                 # XcodeGen 工程描述（生成 .xcodeproj）
├── ExportOptions.plist         # 导出 .ipa 的签名方式（ad-hoc）
└── .github/workflows/build-ipa.yml   # 云构建出 .ipa
```

## 二、本地构建（Mac）

前置：macOS + Xcode 15 及以上、已安装 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）。

```bash
cd iOS/XunJianIOS
brew install xcodegen
xcodegen generate            # 生成 XunJianIOS.xcodeproj
open XunJianIOS.xcodeproj
```

在 Xcode 中：
1. 选择 `XunJianIOS` target → Signing & Capabilities → 选你的 Team（个人免费账号也可，需连真机）。
2. 选择模拟器或真机 → 运行（⌘R）。
3. 真机安装：连上 iPhone → 选设备 → 运行；首次需在手机 设置→通用→VPN与设备管理 中信任开发者。

> 服务器地址默认不写死，首次启动请在登录页填写实际后端地址（如 http://<服务器IP>:8080）。
> 后端即安卓同款 `range-backend-1.0.0.jar`，启动后访问 `http://<IP>:8080` 即可。

## 三、云构建出 .ipa（GitHub Actions）

将本目录推送到 GitHub 仓库，配置以下 **Repository Secrets**（Settings → Secrets and variables → Actions）：

| Secret | 说明 |
|---|---|
| `IOS_CERTIFICATE` | 苹果开发者证书（.p12）的 **base64** 内容 |
| `IOS_CERT_PASSWORD` | .p12 导出密码 |
| `IOS_PROVISIONING_PROFILE` | Ad Hoc/Development 描述文件的 **base64** 内容 |
| `IOS_TEAM_ID` | 开发者 Team ID（如 `ABCDE12345`） |
| `KEYCHAIN_PASSWORD` | CI 临时钥匙串密码（自定义） |

base64 生成方式（Mac）：
```bash
base64 -i cert.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
```

触发：仓库 **Actions → Build iOS IPA → Run workflow**。完成后在 Artifacts 下载 `XunJianIOS-ipa`（含 `.ipa`）。
未配置 Secrets 时，工作流会以自动签名方式打包（适合有 Apple ID 的账号）；导出正式可分发包仍需上述证书与描述文件。

> **不想用 GitHub / 不想花 $99？** 本目录的 `codemagic.yaml` 已改成「**路线2 免费版**」：云 Mac 只出**未签名 IPA**、不碰任何苹果签名；下载后在你 Windows 上用 [Sideloadly](https://sideloadly.app) + **免费 Apple ID** 侧载进手机。详见 **第七节 · 路线 2**。

## 四、与安卓端一致的“预埋缺陷”（便于测试）

- **N1 弱口令**：修改密码接口服务端不校验复杂度，`123456` 之类可直接生效。
- **N2 Token 不失效**：退出登录仅清本地，旧 Token 服务端仍可用。
- **N3 平行越权**：安卓端存在 `/api/tasks?userId=` 越权入口；iOS 端**默认走安全接口**（按当前登录用户归属返回），即仅复刻“正常业务”部分，越权演示仍以安卓端为准。
- **HTTP 明文**：`Info.plist` 已开 `NSAllowsArbitraryLoads`，与安卓 `usesCleartextTraffic` 一致。
- **Token 明文存储**：存于 `UserDefaults`，本身即不安全存储示例。

## 五、注意事项

- AppIcon 当前为空占位，编译会有警告但不影响出包；可往 `XunJianIOS/Assets.xcassets/AppIcon.appiconset` 放图标后重新生成工程。
- 最低支持 iOS 15.0。
- 服务器地址含 IP 时，需与手机在同一局域网，或后端映射到公网。

## 六、纯 Windows 用户出包路径（无 Mac / 不会 GitHub）

> 💡 **不想花 $99？** 直接跳到 **第七节 · 路线 2**：用 Codemagic 云 Mac 出“未签名 IPA” + Windows 的 Sideloadly 免费 Apple ID 侧载，零付费。下面这节是**付费 $99 账号**才需要的路径。

如果你是**只有 Windows、没有 Mac、也不会 GitHub** 的情况，按下面走是唯一能拿到可安装 `.ipa` 的路。先说清两个**绕不过的成本**：

1. **必须花 $99/年 办 Apple 开发者账号**（developer.apple.com）。免费账号无法出可分发的 IPA，这是苹果硬性规定。
2. **必须有一台 iPhone 真机**（要装这个 App），并拿到它的 UDID 注册进描述文件。

### 方案 A：找有 Mac + 付费账号的人代出包（最简，强烈推荐）
把整个 `XunJianIOS/` 文件夹发给任何有 Mac 和付费开发者账号的人，对方：
```
brew install xcodegen
xcodegen generate
open XunJianIOS.xcodeproj   # 选 Team → ⌘R 连真机 → 出包
```
无需你做任何事，对方 3 分钟搞定。

### 方案 B：Codemagic 网页云构建（自己来，不用 GitHub）
Codemagic 提供 Mac 机器，网页点几下即可，比 GitHub Actions 简单：

1. 办 Apple 开发者账号（$99），在后台创建 **App Store Connect API Key**（网页操作，Windows 即可）。
2. 拿到 iPhone 的 **UDID**（连电脑用 iTunes/Finder 或 UDID 类 App 查看），在苹果后台注册该设备。
3. 去 [codemagic.io](https://codemagic.io) 用 GitHub/GitLab/Bitbucket 任一账号登录（仅用来读代码，**无需你会 GitHub 操作**，注册仓库后把 `XunJianIOS/` 内容推上去即可，本仓库已带 `codemagic.yaml`）。
4. Codemagic 网页 → 团队设置 → 集成 → Apple Developer Portal，粘贴第 1 步的 API Key。
5. 启动 `Build iOS IPA` 工作流。它会在 Mac 上自动 `xcodegen generate`、自动从你账号拉证书/描述文件、编译并导出 `.ipa`，构建完成后直接下载。

> 本目录的 `codemagic.yaml` 已配置：`app-store-connect fetch-signing-files` 自动拉取 Ad Hoc 描述文件，`xcode-project use-profiles` 自动套用签名，你**不需要手动准备 .p12 证书**。

### 方案 C：租云 Mac 自己编译
租 MacStadium / AWS EC2 Mac / Scaleway 等云 Mac，按「二、本地构建」步骤操作（同样需要 $99 账号 + iPhone UDID）。

## 七、不花 $99 的免费侧载方案（有 iPhone + 免费 Apple ID 即可）

不办付费开发者账号，也能把 App 装进**你自己的** iPhone——靠苹果允许用**免费 Apple ID（个人团队）**做开发侧载。限制：App 有效期 **7 天**（到期重签即可）、同一免费账号最多同时 **3 个 App**、仅限本机。

### 路线 1：借一台 Mac，10 分钟搞定（最省事，强烈推荐）
1. Mac 上装 Xcode（App Store 免费）。
2. Xcode → Settings → Accounts → 登录你的 Apple ID（**免费即可，不要付费**）。
3. 打开本工程 `XunJianIOS.xcodeproj`（需先 `xcodegen generate`）。
4. 选 `XunJianIOS` target → Signing & Capabilities → Team 选你的 Apple ID（个人团队），Xcode 自动生成免费描述文件。
5. iPhone 连 Mac → 信任电脑 → 选设备 → ⌘R 运行。App 直接装好可用。
6. 7 天后过期，重连 Mac 再 ⌘R 一次即续期。**本工程已可直接这样跑**，无需改配置。

### 路线 2：完全不碰 Mac（云 Mac 编译 + Windows 侧载）— 你选的路

本路线**不需要 $99 付费账号、不需要任何苹果证书/描述文件**，全程在 Windows 点鼠标完成。前提：你有一个普通 **Apple ID（免费即可）+ 一台 iPhone**。

> 你已能访问 GitHub，**直接走 GitHub 最省事**（第 1 步用 GitHub）；若某天又打不开，再走下面的 Gitee 备选。

**第 1 步：把工程放进一个 git 仓库**
- **GitHub（推荐，能访问就用）**：打开 [github.com](https://github.com) → 右上角 **+ → New repository** → 仓库名如 `XunJianIOS`、**设为 Public**、**不要**勾 “Add a README” → 创建后把本目录内容**整体拖到网页上传区**（GitHub 网页支持拖拽整个文件夹，会自动提交）。**仓库根目录必须直接是 `codemagic.yaml`**（它已在根），不要把 `iOS/` 这层也传上去。
- **Gitee 备选（GitHub 打不开时）**：[gitee.com](https://gitee.com) 新建**公开**仓库 → 同样把本目录内容拖到网页上传区，仓库根直接是 `XunJianIOS/` 里的内容（`codemagic.yaml` 在根）。

**第 2 步：到 Codemagic 发起构建（自带 Mac 机器，免费 500 分钟/月）**
1. 打开 [codemagic.io](https://codemagic.io) → 用 **GitHub 授权登录**（最快，会自动关联你的 GitHub 仓库）。
2. 左侧 **Apps → Add application** → 选 **GitHub** → 找到第 1 步那个 `XunJianIOS` 仓库 → 下一步，Codemagic 自动识别根目录的 `codemagic.yaml`。
3. 点击 **Start new build**。
4. 构建全程**无需配置任何 Apple 凭据**（本 `codemagic.yaml` 已是“未签名 IPA”版本）。
5. 跑完后在 **Artifacts** 里下载 `XunJianIOS.ipa`（这就是未签名的安装包）。

**第 3 步：Windows 上用 Sideloadly 侧载进 iPhone**
1. Windows 安装 [Sideloadly](https://sideloadly.app)（免费）。
2. iPhone 用数据线连电脑，手机点“信任”。
3. Sideloadly 里：
   - **IPA 文件** → 选第 2 步下载的 `XunJianIOS.ipa`
   - **Apple ID** → 填你的**免费** Apple ID 邮箱 + 密码
   - 点 **Start** → 它会用你的免费账号重新签名并安装到手机。
4. 手机：设置 → 通用 → VPN 与设备管理 → 信任该开发者。
5. App 出现在桌面即可用。**7 天有效期**，过期后在 Sideloadly 里再点一次 **Start** 重签即可（无需重新下载 IPA）。

> 备注：两条路线都仍需**至少一次在 Mac 上编译出二进制**（路线 1 是借来的 Mac，路线 2 是 Codemagic 的云 Mac）。**Windows 本身永远无法编译 iOS**，这是绕不过的。但 $99 确实可以省掉。

