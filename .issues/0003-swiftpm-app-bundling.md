---
id: 0003
title: "SwiftPM 可执行文件打包成菜单栏 .app 的方案"
labels: [wayfinder:research]
status: open
claimed-by: ""
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

（待研究 session 填写）
