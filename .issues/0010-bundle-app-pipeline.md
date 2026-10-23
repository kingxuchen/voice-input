---
id: "0010"
title: "打包管线：bundle-app.sh → ad-hoc .app"
labels: [ready-for-agent]
status: open
claimed-by: ""
blocked-by: ["0007"]
---

## Parent

[0006 VoiceInput v1 实现规格](0006-voiceinput-v1-spec.md)（模板照 research/swiftpm-app-bundling.md）

## What to build

一条脚本从 SwiftPM 构建产物组装可日常使用的 `.app`：`swift build -c release --show-bin-path` 动态定位产物 → 组装标准 bundle 目录（Info.plist 含 `LSUIElement=true`、`CFBundleIdentifier=com.fanbingbing.voiceinput`）→ `plutil -lint` 校验 → ad-hoc 签名。产物安装到 `/Applications` 后双击即可常驻运行（无 Dock 图标），与 `swift run` 行为一致。可与 0008/0009 并行。

## Acceptance criteria

- [ ] 一条命令完成 构建 → 组装 → 校验 → 签名；不写死 `.build` 路径
- [ ] Info.plist 含 `LSUIElement=true` 与 `com.fanbingbing.voiceinput`，`plutil -lint` 通过
- [ ] ad-hoc 签名用 `codesign --force --sign -`（.app 根，不用 `--deep`）
- [ ] 安装到 `/Applications` 后双击运行：无 Dock 图标、无主窗口、菜单栏常驻
- [ ] 脚本可重复执行覆盖更新（幂等），重编后签名状态正常
