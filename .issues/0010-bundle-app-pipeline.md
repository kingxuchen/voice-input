---
id: "0010"
title: "打包管线：bundle-app.sh → ad-hoc .app"
labels: [ready-for-agent]
status: closed
claimed-by: "agent-0010"
blocked-by: ["0007"]
---

## Parent

[0006 VoiceInput v1 实现规格](0006-voiceinput-v1-spec.md)（模板照 research/swiftpm-app-bundling.md）

## What to build

一条脚本从 SwiftPM 构建产物组装可日常使用的 `.app`：`swift build -c release --show-bin-path` 动态定位产物 → 组装标准 bundle 目录（Info.plist 含 `LSUIElement=true`、`CFBundleIdentifier=com.fanbingbing.voiceinput`）→ `plutil -lint` 校验 → ad-hoc 签名。产物安装到 `/Applications` 后双击即可常驻运行（无 Dock 图标），与 `swift run` 行为一致。可与 0008/0009 并行。

## Acceptance criteria

- [x] 一条命令完成 构建 → 组装 → 校验 → 签名；不写死 `.build` 路径
- [x] Info.plist 含 `LSUIElement=true` 与 `com.fanbingbing.voiceinput`，`plutil -lint` 通过
- [x] ad-hoc 签名用 `codesign --force --sign -`（.app 根，不用 `--deep`）
- [ ] 安装到 `/Applications` 后双击运行：无 Dock 图标、无主窗口、菜单栏常驻（用临时 `MenuBarExtra` 工程验证过行为，等 0007 真实工程合入后复验）
- [x] 脚本可重复执行覆盖更新（幂等），重编后签名状态正常

## Resolution

- 交付 `scripts/bundle-app.sh`（唯一文件）：`swift build -c release --show-bin-path` 动态定位产物 → 组装 `Contents/{Info.plist, PkgInfo, MacOS/VoiceInput, Resources/}` → `plutil -lint` → `codesign --force --sign - --timestamp=none`（.app 根，无 `--deep`）→ `codesign --verify --strict`。
- Info.plist 由脚本 heredoc 生成（不另存模板文件），bundle id 取 SPEC 0006 定稿的小写 `com.fanbingbing.voiceinput`（research 报告里的大写 `com.fanbingbing.VoiceInput` 是笔误，已按 SPEC 改正）。
- 资源束拷贝（`*.bundle` → `Contents/Resources/`）已实现，规避 P-07 的 `Bundle.module` Fatal Error。
- 支持 `--install [目录]`（默认 `~/Applications`）、`--no-build`、`--help`。安装前会比对目标处已有同名 app 的 bundle id，来源不明则中止不删。
- 验证：临时最小 SwiftPM 工程（含 `resources:`）跑通 构建→组装→lint→签名→verify 全流程，`codesign -d -r-` 可见 designated requirement（`cdhash H"..."`）；另用真实 `MenuBarExtra` 工程实测：无 Dock 图标、窗口数 0、菜单栏状态项 `com.fanbingbing.voiceinput` 存在且随进程生死。临时工程已清理干净。
- 待办：0007 合入后用真实工程跑一次 `--install /Applications` 双击验收（票内第 4 条 AC）。
