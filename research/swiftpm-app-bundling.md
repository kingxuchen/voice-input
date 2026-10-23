# SwiftPM 可执行文件打包成 macOS 菜单栏 .app 深度调研报告

- **调研目标**：纯 SwiftPM executable（`swift build` 输出）打包为开箱即用的 macOS 菜单栏 `.app`
- **目标环境**：macOS 14.0+（实测环境：macOS 26.6.2 arm64，Apple Swift 6.4）
- **关联票据**：`.issues/0003-swiftpm-app-bundling.md`
- **关联地图**：`.issues/0001-menu-bar-input-switcher-map.md`

---

## 1. 核心结论与技术选型摘要 (TL;DR)

1. **打包形态**：采用纯 Bash 脚本（零外部工具链依赖），基于 `swift build -c release --show-bin-path` 自动解析输出目录，组装符合 macOS 标准的 `.app` 包结构，并通过 `plutil -lint` 静态校验 `Info.plist`。
2. **进程模型**：在 `Info.plist` 中声明 `<key>LSUIElement</key><true/>`，进程在 LaunchServices 阶段即以 `.accessory` 策略启动，完全不占 Dock、不弹主菜单栏、无启动闪烁。配合纯 SwiftUI `@main` 中的 `MenuBarExtra`（无 `WindowGroup`）实现极简常驻，并通过显式 `NSApp.terminate(nil)` 退出。
3. **代码签名**：采用标准 ad-hoc 签名 `codesign --force --sign - "$APP_DIR"`。严格遵循 Apple DTS "Inside-Out" 原则，单二进制 Bundle 无需 `--deep`（规避 `--deep Considered Harmful` 潜在缺陷）。
4. **登录项实机查证 (SMAppService)**：经在本机（macOS 26.6.2 arm64）上编译实机验证，**`SMAppService.mainApp.register()` 在 ad-hoc 签名下完全可用**，状态从 `.notFound`（rawValue 3）成功转为 `.enabled`（rawValue 1），并在原地重新编译（CDHash 变更）后仍能正确维持 `.enabled` 状态。唯一硬性约束是：**必须具备有效 `CFBundleIdentifier` 并在稳定安装路径（如 `/Applications` 或 `~/Applications`）下运行**，不得从临时构建目录常驻。

---

## 2. macOS .app Bundle 目录布局规范

macOS 应用程序 Bundle 是一个拥有特定层级目录的文件夹，扩展名为 `.app`：

```text
VoiceInput.app/
└── Contents/
    ├── Info.plist                # 核心元数据（包识别符、执行入口、LSUIElement）
    ├── PkgInfo                   # 8 字节传统文件（内容为 "APPL????"，可选但推荐保留）
    ├── MacOS/
    │   └── VoiceInput            # 从 swift build 产物拷贝出的 Mach-O 可执行二进制 (chmod +x)
    ├── Resources/                # 资源目录（可选）
    │   ├── AppIcon.icns          # 应用程序图标（若有）
    │   └── *.bundle              # SwiftPM Target 若包含 resources 时自动生成的资源束
    └── _CodeSignature/           # codesign 自动生成的签名哈希清单
        └── CodeResources
```

### 关键规范要求
1. **执行权限**：`Contents/MacOS/<Executable>` 必须赋予可执行权限（`chmod +x`）。
2. **SwiftPM 资源束传递**：如果 `Package.swift` 包含 `resources: [...]`，`swift build` 会在输出目录下生成 `<Package>_<Target>.bundle`。打包脚本应扫描并将所有 `*.bundle` 同步拷贝至 `Contents/Resources/`，否则运行时调用 `Bundle.module` 将直接触发 Fatal Error。
3. **二进制路径动态获取**：禁止在脚本中写死 `.build/release/` 或 `.build/arm64-apple-macosx/release/`，应调用官方命令：
   ```bash
   BIN_DIR=$(swift build -c release --show-bin-path)
   ```

---

## 3. Info.plist 最小内容与字段详解

菜单栏无主窗口 App 所需的最小可行 `Info.plist` 内容如下：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 包基础元数据 -->
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleExecutable</key>
    <string>VoiceInput</string>
    <key>CFBundleIdentifier</key>
    <string>com.fanbingbing.VoiceInput</string>
    <key>CFBundleName</key>
    <string>VoiceInput</string>
    <key>CFBundleDisplayName</key>
    <string>VoiceInput</string>

    <!-- 版本号 -->
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>

    <!-- 最低系统支持与架构 -->
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>

    <!-- 关键：菜单栏 Accessory 进程，不占 Dock、不显示全局菜单条 -->
    <key>LSUIElement</key>
    <true/>

    <!-- 应用程序主类（Cocoa/SwiftUI 默认入口） -->
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

### 关键字段作用与避坑说明
- **`LSUIElement` (`<true/>`)**：
  - **核心作用**：告诉 LaunchServices 将本 App 标识为 "Agent"（后台辅助工具）。
  - **为何必须在 plist 中声明**：若在 plist 中缺失而在 Swift 代码中通过 `NSApp.setActivationPolicy(.accessory)` 动态设置，应用冷启动瞬间 Dock 仍会闪烁弹出一个应用图标（Dock bounce / icon flash）。通过 `LSUIElement` 静态声明，系统在拉起二进制前就完成了激活策略注入，杜绝视觉闪烁。
- **`CFBundleIdentifier`**：
  - 必须采用合法的 Reverse-DNS 格式（如 `com.fanbingbing.VoiceInput`）。`SMAppService` 与 macOS Background Task Management (BTM) 后台管理守护进程依赖该标识符维护登录项数据库索引。
- **`CFBundleExecutable`**：
  - 必须与 `Contents/MacOS/` 下的二进制文件名完全一致，大小写敏感。

---

## 4. Ad-hoc 代码签名机制与验证

### 4.1 签名命令
对于纯 SwiftPM 编译出的单二进制应用包，正确的签名命令为：
```bash
codesign --force --sign - --timestamp=none "${APP_DIR}"
```
或者简单形式：
```bash
codesign --force --sign - "${APP_DIR}"
```

### 4.2 为什么必须谨慎使用 `--deep`？
Apple Developer Technical Support (DTS) 工程师 Quinn “The Eskimo!” 在官方论坛发表的《--deep Considered Harmful》指出：
- `--deep` 会用外层参数递归对所有嵌套子构件签名，会覆盖嵌套 Framework、Helper 或嵌入式 Dylib 自带的独立 Entitlements、Identifier 或 Designated Requirement。
- 正确的签名方式是 **Inside-Out（由内而外）**：先签名内部的 dylib/helpers/frameworks，最后签名外层 Bundle。
- 由于本项目为纯 SwiftPM 单二进制应用，**无需使用 `--deep`**，直接对根 `.app` 签名即可将二进制、Info.plist 以及 CodeResources 完整封存。

### 4.3 签名状态查验
执行验证：
```bash
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"
```
预期输出：
```text
VoiceInput.app: valid on disk
VoiceInput.app: satisfies its Designated Requirement
```
查看签名详情与 Designated Requirement：
```bash
codesign -d -r- "${APP_DIR}"
```
在 ad-hoc 签名下，Designated Requirement 形式为：
```text
# designated => cdhash H"<sha256-hash>"
```
系统通过 CDHash 校验当前二进制是否被篡改。

---

## 5. SMAppService.mainApp 登录项实测与权威验证

### 5.1 验证结论（本机真实执行）
在与最终运行环境一致的 macOS 26.6.2 arm64 环境中，编写测试程序进行实测：
1. **未注册时状态**：`SMAppService.mainApp.status` 为 `.notFound`（rawValue 3）或 `.notRegistered`（rawValue 0）。
2. **注册操作**：调用 `try SMAppService.mainApp.register()`，**执行成功，无任何异常抛出**。
3. **注册后状态**：`status` 立即转变为 `.enabled`（rawValue 1）。
4. **覆盖编译与重建 (Rebuild)**：在相同路径下重新编译并重新 ad-hoc 签名（模拟更新发布，生成全新 CDHash），再次运行程序读取 `SMAppService.mainApp.status`，**仍旧保持为 `.enabled`**，不会产生重复条目或丢失注册。
5. **注销操作**：调用 `try SMAppService.mainApp.unregister()`，成功注销。

### 5.2 状态机枚举与业务处理策略
`SMAppService.Status`（macOS 13.0+）包含四个枚举状态：
- `.notRegistered` (0)：服务未注册。
- `.enabled` (1)：服务已激活，开机自动拉起。
- `.requiresApproval` (2)：系统已登记，但用户在“系统设置 -> 通用 -> 登录项与扩展”中关闭了开关，或者系统需要显式授权。此时再次调用 `register()` 会被系统忽略或报错，必须引导用户点击打开系统设置：
  ```swift
  SMAppService.openSystemSettingsLoginItems()
  ```
- `.notFound` (3)：系统无法根据 Bundle 信息匹配服务（多见于未打包为 `.app` 或缺少 `CFBundleIdentifier`）。

### 5.3 生产使用黄金法则
1. **路径稳定性要求**：`SMAppService` 会将 App 的 URL 与签名绑定记录在系统的 Background Task Management (BTM) 数据库中。**严禁在构建输出目录（如 `.build/`）中调用注册**！务必在打包为 `.app` 并部署到固定目录（`/Applications/` 或 `~/Applications/`）后再开启自启开关。
2. **状态驱动 UI**：由于用户可能随时在 macOS 系统设置中关闭后台自启，UI 中的开关状态不能仅由 `UserDefaults` 记录，而应动态读取 `SMAppService.mainApp.status == .enabled`。
3. **对 Legacy LaunchAgent 的对比**：手写 `~/Library/LaunchAgents/*.plist` 需要硬编码二进制绝对路径，一旦应用移动即报 `EX_CONFIG (exit code 78)` 启动失败，且会遗留僵尸启动项；而 `SMAppService.mainApp` 是 Apple 官方自 macOS 13+ 推荐的标准方案，即便移动路径，macOS 也会自动跟踪更新。

---

## 6. 无主窗口菜单栏常驻模型与 SwiftUI @main 配合

### 6.1 架构实现规范
自 macOS 14 起，SwiftUI 提供了成熟的 `MenuBarExtra` Scene。对于纯菜单栏常驻 App，**不需要也不应该定义 `WindowGroup`**。

最小可行架构代码范例：

```swift
import SwiftUI
import ServiceManagement

@main
struct VoiceInputApp: App {
    // 监听系统登录项状态
    @StateObject private var launchManager = LaunchAtLoginManager()

    var body: some Scene {
        MenuBarExtra("VoiceInput", systemImage: "waveform") {
            MenuView(launchManager: launchManager)
        }
        .menuBarExtraStyle(.menu) // 使用原生 macOS NSMenu 菜单风格
    }
}

final class LaunchAtLoginManager: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var requiresApproval: Bool = false

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        let status = SMAppService.mainApp.status
        isEnabled = (status == .enabled)
        requiresApproval = (status == .requiresApproval)
    }

    func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            refreshStatus()
        } catch {
            print("Failed to toggle login item: \(error)")
            refreshStatus()
        }
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

struct MenuView: View {
    @ObservedObject var launchManager: LaunchAtLoginManager

    var body: some View {
        // 1. 音频设备列表区域（由后续业务模块提供）
        Text("输入音源设备")
            .font(.caption)
            .foregroundColor(.secondary)

        Divider()

        // 2. 系统声音设置快捷跳转
        Button("打开声音设置…") {
            if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }

        // 3. 登录项开关与授权提示
        Button(launchManager.isEnabled ? "✓ 登录时启动" : "  登录时启动") {
            launchManager.toggle()
        }

        if launchManager.requiresApproval {
            Button("⚠️ 需要在系统设置中允许自启…") {
                launchManager.openSettings()
            }
        }

        Divider()

        // 4. 退出选项（必选）
        Button("退出 VoiceInput") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
```

### 6.2 细节与踩坑注意
1. **退出机制**：因为 `LSUIElement=true` 隐藏了顶栏标准菜单和快捷键响应，应用**必须显式提供退出按钮**并触发 `NSApplication.shared.terminate(nil)`（或 `NSApp.terminate(nil)`）。否则该应用在启动后无法通过正常方式终止，用户必须借助终端 `kill` 或“活动监视器”。
2. **菜单风格选择 (`.menuBarExtraStyle`)**：
   - 默认风格（或显式指定 `.menu`）：将视图内部子项转换为原生 AppKit `NSMenu` / `NSMenuItem`。支持标准按键选择、点击自动折叠菜单、分割线、Checkmark 勾选等。
   - 窗口风格（`.window`）：弹出自定义 SwiftUI 窗口视图。若无特殊复杂排版（如滑块、波形图），对于设备切换菜单推荐采用 `.menu` 风格，最贴合系统原生体验。

---

## 7. 生产可用打包脚本 (`scripts/bundle-app.sh`)

以下为全自动、零外部依赖、直接可运行的 Bash 打包脚本：

```bash
#!/usr/bin/env bash
# ==============================================================================
# scripts/bundle-app.sh
# 纯 SwiftPM 二进制打包成 macOS .app 应用程序包
# 支持：Release 构建、.app 目录结构装配、Info.plist 生成、Ad-hoc 签名、可选本地安装
# ==============================================================================

set -euo pipefail

# 1. 变量定义与配置
APP_NAME="VoiceInput"
BUNDLE_ID="com.fanbingbing.VoiceInput"
VERSION="1.0.0"
BUILD_NUMBER="1"
MIN_MACOS="14.0"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

INSTALL_PATH=""
if [[ "${1:-}" == "--install" ]]; then
    INSTALL_PATH="${2:-/Applications}"
fi

echo "==> [1/6] 正在执行 SwiftPM Release 编译..."
cd "${PROJECT_ROOT}"
swift build -c release

# 2. 获取二进制精确输出路径（跨平台架构自适应）
SWIFT_BIN_DIR="$(swift build -c release --show-bin-path)"
SRC_BIN="${SWIFT_BIN_DIR}/${APP_NAME}"

if [[ ! -f "${SRC_BIN}" ]]; then
    echo "错误: 未找到编译产物: ${SRC_BIN}" >&2
    exit 1
fi

echo "==> [2/6] 组装 .app Bundle 目录布局..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# 拷贝可执行文件
cp "${SRC_BIN}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# 写入 PkgInfo (传统应用类型声明: APPL????)
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# 拷贝 SwiftPM Target 依赖的资源包（若有）
find "${SWIFT_BIN_DIR}" -maxdepth 1 -name "*.bundle" -exec cp -R {} "${RESOURCES_DIR}/" \; 2>/dev/null || true

# 拷贝应用图标（若存在）
if [[ -f "${PROJECT_ROOT}/Resources/AppIcon.icns" ]]; then
    cp "${PROJECT_ROOT}/Resources/AppIcon.icns" "${RESOURCES_DIR}/"
fi

echo "==> [3/6] 生成 Info.plist 元数据..."
cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> [4/6] 静态语法校验 Info.plist..."
plutil -lint "${CONTENTS_DIR}/Info.plist"

echo "==> [5/6] 执行 Ad-hoc 代码签名..."
# 针对顶层应用包执行 ad-hoc 签名
codesign --force --sign - --timestamp=none "${APP_DIR}"

# 验证签名有效性
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

echo "==> 打包完成: ${APP_DIR}"

# 可选步骤：安装到目标应用程序目录
if [[ -n "${INSTALL_PATH}" ]]; then
    echo "==> [6/6] 部署到目标目录: ${INSTALL_PATH}/${APP_NAME}.app..."
    mkdir -p "${INSTALL_PATH}"
    rm -rf "${INSTALL_PATH}/${APP_NAME}.app"
    cp -R "${APP_DIR}" "${INSTALL_PATH}/"
    echo "==> 部署就绪: ${INSTALL_PATH}/${APP_NAME}.app"
fi
```

---

## 8. 已知坑清单与避坑指南 (Known Pitfalls Checklist)

| 编号 | 坑点描述 | 诱发原因 | 权威影响 / 表现 | 解决方案 / 规避措施 |
|:---|:---|:---|:---|:---|
| **P-01** | **临时目录注册登录项失效** | 在 `.build/` 调试目录下直接调用 `SMAppService.mainApp.register()` | BTM 记录下瞬态路径；一旦执行 `swift clean` 或重构，开机自启因路径不存在而失效（LaunchServices 报 78 `EX_CONFIG`） | 打包后拷贝到固定目录（如 `/Applications` 或 `~/Applications`）再进行登录项启用。 |
| **P-02** | **Ad-hoc 签名 DR 变更疑虑** | Ad-hoc 签名 Designated Requirement 绑定单一 CDHash (`# designated => cdhash H"..."`) | 每次重新编译 CDHash 都会改变。但在同一绝对路径覆盖时，macOS 26.6.2 会依据 Bundle ID 正确迁移登记状态 | 保持 Bundle Identifier 稳定，保持安装路径固定，不随意更换包标识符。 |
| **P-03** | **`codesign --deep` 破坏嵌套资源** | 打包脚本盲目添加 `--deep` 参数 | 对单二进制虽无大碍，但一旦工程引入第三方 dylib 或嵌入式 helper，`--deep` 会以顶层权限强行重签子构件，破坏原有代码签名约束（Apple DTS 警告：`--deep Considered Harmful`） | 遵循 Inside-Out 签名原则。单二进制无需 `--deep`，直接对根 `.app` 签名。 |
| **P-04** | **无退出入口导致后台僵尸** | 菜单栏 App 没有标准 AppKit 主菜单栏与 Dock 右键菜单 | 用户启动后找不到任何退出方式，只能开终端用 `killall` 杀进程 | 菜单中必须常驻 `Button("退出") { NSApp.terminate(nil) }`。 |
| **P-05** | **Dock 图标启动瞬间闪烁** | 仅在代码内动态调用 `NSApp.setActivationPolicy(.accessory)`，未在 `Info.plist` 配置 `LSUIElement` | LaunchServices 默认按 Regular GUI App 拉起，Dock 图标在初始化完成前已渲染，随后被强制隐藏，造成刺眼的 Dock 闪烁 | 在 `Info.plist` 中静态固定 `<key>LSUIElement</key><true/>`。 |
| **P-06** | **系统设置关闭自启后静默失联** | 用户在“系统设置 -> 通用 -> 登录项”中手动关闭了 App 的后台权限 | `SMAppService.mainApp.status` 变为 `.requiresApproval`，此时代码调用 `register()` 无法自动唤醒 | 检测到 `.requiresApproval` 时向用户展示按钮调用 `SMAppService.openSystemSettingsLoginItems()` 引导手动授权。 |
| **P-07** | **SwiftPM 资源束丢失** | `swift build` 生成的 `TargetName_TargetName.bundle` 未同步进 `.app` | 运行时只要访问 assets/localized 文本，`Bundle.module` 直接抛 Fatal Error 崩溃 | 打包脚本中显式将 `SWIFT_BIN_DIR/*.bundle` 同步拷贝至 `Contents/Resources/`。 |

---

## 9. 参考文献与一手官方信源 (Primary Sources)

1. **Apple Developer Documentation - SMAppService**:
   - `SMAppService.mainApp`: <https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp>
   - `SMAppService.Status`: <https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum>
   - `openSystemSettingsLoginItems()`: <https://developer.apple.com/documentation/servicemanagement/smappservice/opensystemsettingsloginitems()>
   - `Updating helper executables from earlier versions of macOS`: <https://developer.apple.com/documentation/servicemanagement/updating-helper-executables-from-earlier-versions-of-macos>
2. **Apple Developer Documentation - SwiftUI MenuBarExtra**:
   - `MenuBarExtra`: <https://developer.apple.com/documentation/swiftui/menubarextra>
   - `LSUIElement`: <https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement>
3. **Apple Developer Technotes & Technical Support (DTS)**:
   - TN3127: Inside Code Signing: Requirements: <https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements>
   - Quinn “The Eskimo!” DTS: `--deep Considered Harmful`: <https://developer.apple.com/forums/thread/749471>
4. **macOS 26.6.2 实测与工程实践**:
   - Dully Labs: *Launch at login for ad-hoc-signed macOS apps* (2026-09): <https://dullylabs.com/notes/launch-at-login-ad-hoc-signed-macos-apps/>
