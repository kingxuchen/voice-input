---
id: 0001
title: "菜单栏输入音源切换器 — Wayfinder 地图"
labels: [wayfinder:map]
status: open
---

## Destination

在 `voice-input/` 目录落地一个可日常使用的 macOS 菜单栏输入切换 App：常驻菜单栏，展开即列出所有含输入流的音频设备（含虚拟设备），点击即设为系统默认输入。本地图管到"路线清晰"——所有决策定稿为一份可照做的实现蓝图（SPEC.md）；编码执行由后续 session 完成，不在这张图内。

## Notes

- 语言/背景：中文交流。主人饭饼饼（前端工程师），本机 macOS 26.6.2（arm64），Swift 6.4 工具链。动机：服务于听写工作流（Type4Me/闪电说等；已有记忆：遥控器混音链路写入虚拟设备 vRemoteDr 2ch）。本图只画通用切换器，联动进雾区。
- 建图时已定决策（两轮 grilling，2026-10-23，11 项全部落定）：
  1. 点击设备 = 设置系统全局默认输入（Core Audio）；不做按 app 路由。
  2. 设备范围：所有具备输入流的设备（物理 + 虚拟，如 vRemoteDr 2ch、BlackHole），按"有无输入流"过滤。
  3. UI：SwiftUI `MenuBarExtra`；最低 macOS 14。
  4. 实时刷新：监听 `kAudioHardwarePropertyDevices` 与 `kAudioHardwarePropertyDefaultInputDevice`，设备增减/默认变更时菜单与勾选自动跟随。
  5. 开机自启：菜单内开关，用 `SMAppService`。
  6. 分发：个人自用，本地构建 + ad-hoc 签名 `.app`，不公证。
  7. 项目形态：SwiftPM 可执行（无 .xcodeproj），脚本打 `.app`。
  8. 菜单（v1）：设备列表（勾选当前默认）／分隔线／打开系统声音设置／登录时启动开关／退出。
- HITL 票建议加载 skills：grilling、domain-modeling；研究票加载 research。
- 追踪器约定（本地 markdown）：`.issues/` 每票一文件；front-matter `status: open|closed`、`claimed-by`、`blocked-by`（票 id 列表）。答案写进票内 `## Resolution` 段后置 closed；完成票的 session 在本地图 "Decisions so far" 追加一行（研究 subagent 不动地图，由主线 session 代追加，避免并发冲突）。研究产物放 `research/*.md`，票里链接（仓库无远端，不开分支）。
- 边界：一张票一个 session；研究票可并行。

## Decisions so far

- [Core Audio 方案核查](0002-coreaudio-api-verification.md)（closed 2026-10-23）：100% 原生 Core Audio HAL C API、零三方依赖（SimplyCoreAudio 2024-03 已归档且不支持 Swift 6 严格并发）；Swift 6 桥接模式 = 顶层 `nonisolated` C 函数指针回调 + `Unmanaged` 传 self + `Task { @MainActor }` 跳板 + `isolated deinit` 注销，Swift 6.4 实测 0 警告 0 错误；CFString 用 `takeRetainedValue()` 防泄漏；仅设默认输入不创建音频流，不触发蓝牙 HFP/SCO 降级（+50ms 防抖）；MenuBarExtra 菜单内容解耦为独立子视图 + `@Observable` 管理器驱动热插拔刷新。报告：research/coreaudio-api-verification.md
- [SwiftPM 打包 .app](0003-swiftpm-app-bundling.md)（closed 2026-10-23）：纯 bash 脚本用 `swift build -c release --show-bin-path` 动态定位产物组装 `.app`（禁止写死 .build 路径）；`Info.plist` 置 `LSUIElement=true` 由 LaunchServices 直接 `.accessory` 启动、免 Dock 闪烁；ad-hoc 签名 `codesign --force --sign -` 于 .app 根、不用 `--deep`；本机实测 `SMAppService.mainApp.register()` 兼容 ad-hoc（CDHash 变更后仍 .enabled），硬要求 = 正规反域名 CFBundleIdentifier + 固定路径（/Applications 等）安装；权限被关时 `.requiresApproval` 需引导 `openSystemSettingsLoginItems()`。模板：research/swiftpm-app-bundling.md

## Not yet specified

- 输入电平表（每设备输入电平/VU 指示）
- 全局快捷键（呼出菜单/循环切换设备）
- 听写 app 联动与自动切换规则（某 app 前台自动切输入、CLI/URL scheme 供 Type4Me 等调用）
- 菜单视觉细化（SF Symbol 图标、设备类型图标、App 名称与中文名）
- 通用二进制（Intel）/多机部署——仅当从自用扩展时

## Out of scope

- 按 app 的输入路由（HAL 插件/私有 API 深水区，建图时已否决）
- 只显示不切换的纯只读形态（已否决）
- 输出设备切换（本 destination 只画输入；想要另开新图）
- App Store / Developer ID 公证等对外分发（已定自用；日后想要另开图）
- Xcode 项目形态（已定 SwiftPM）
- macOS 13 及以下兼容
