---
id: 0003
title: "SwiftPM 可执行文件打包成菜单栏 .app 的方案"
labels: [wayfinder:research]
status: closed
claimed-by: "research-agent-0003"
blocked-by: []
---

## Question

纯 SwiftPM executable（`swift build` 出的二进制）如何变成可日常使用的菜单栏 `.app`：

- Info.plist 要点：`LSUIElement=true`（不占 Dock）、bundle id、版本号——最小可行内容。
- 打包脚本形态：.app 目录布局、`codesign --sign -`（ad-hoc）步骤、可重复构建。
- `SMAppService.mainApp` 注册登录项对 bundle 的要求（正规 bundle id/签名是否必需，ad-hoc 是否可用）。
- 菜单栏 App 长驻的进程模型（无主窗口，`NSApplication` 激活策略 `.accessory`）与 SwiftPM `@main` 入口的配合（SwiftUI `App` 协议 vs 手动 `NSApplication`）。
- 结论需给出：可直接执行的打包脚本 + Info.plist 模板 + 已知坑清单。以 Apple 官方文档与一手实践为准。

## Resolution

详细调研报告与可直接执行的代码/模板见：[research/swiftpm-app-bundling.md](../research/swiftpm-app-bundling.md)。

### 推荐方案
采用纯 Bash 脚本调用 `swift build -c release --show-bin-path` 自动解析路径并装配 `.app` 目录结构（含 `Contents/MacOS`、`Contents/Resources` 与 `Info.plist`）；在 `Info.plist` 中声明 `LSUIElement=true` 静态指定 `.accessory` 激活策略；采用 ad-hoc 签名 `codesign --force --sign -`；开机自启采用现代 `SMAppService.mainApp` API，并在安装到固定目录（如 `/Applications` 或 `~/Applications`）后注册。

### 关键结论
1. **SMAppService.mainApp 兼容 ad-hoc 签名（实测通过）**：本机 macOS 26.6.2 arm64 实测证明，ad-hoc 签名的 `.app` 调用 `SMAppService.mainApp.register()` 可顺利由 `.notFound` 转为 `.enabled`，重新编译更新（CDHash 变化）后状态仍稳定维持。硬性要求是必须具备合法的 Reverse-DNS `CFBundleIdentifier` 并在固定路径运行（避免在 `.build/` 临时路径注册）。
2. **进程模型与 SwiftUI @main**：在 `Info.plist` 中配置 `<key>LSUIElement</key><true/>` 可在 LaunchServices 阶段直接以 `.accessory` 启动，杜绝 Dock 图标闪烁。SwiftUI 入口采用纯 `MenuBarExtra` Scene（无 `WindowGroup`），必须在菜单底部显式提供 `Button("退出") { NSApp.terminate(nil) }` 避免僵尸常驻。
3. **Ad-hoc 代码签名规避 --deep**：遵循 Apple DTS（Quinn "The Eskimo!"）Inside-Out 签名原则，单二进制包直接对 `.app` 根目录执行 `codesign --force --sign -` 即可，坚决避免 `--deep` 对嵌套组件产生潜在污染。
4. **自启授权异常处理**：若用户在“系统设置 -> 登录项与扩展”中关闭了自启权限，`SMAppService.mainApp.status` 将处于 `.requiresApproval` 状态，此时再次调用 `register()` 无效，需在 UI 引导用户调用 `SMAppService.openSystemSettingsLoginItems()` 手动恢复。
5. **打包脚本自动化交付**：产出完整、零外部依赖的 `scripts/bundle-app.sh` 模板，支持静态 `plutil -lint` 语法检查与可选 `--install` 部署流程。
