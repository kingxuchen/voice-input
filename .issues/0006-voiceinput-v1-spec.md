---
id: 0006
title: "VoiceInput v1 实现规格（SPEC）— 菜单栏输入音源切换器"
labels: [wayfinder:spec, ready-for-agent]
status: open
claimed-by: ""
blocked-by: []
---

# VoiceInput v1 实现规格

汇总自：[0002 Core Audio 方案核查](0002-coreaudio-api-verification.md) · [0003 SwiftPM 打包](0003-swiftpm-app-bundling.md) · [0004 行为规格定稿](0004-behavior-spec.md)（证据与代码骨架见 `research/` 两份报告）。

## Problem Statement

在 macOS 上切换输入音源需要打开系统设置 → 声音 → 输入，再在列表里选择，路径深、无快捷入口。主人（前端工程师，重度听写工作流：Type4Me/闪电说）日常需要在内置麦克风、USB 麦克风与虚拟混音设备（vRemoteDr 2ch）之间反复切换，这个高频操作目前成本过高。

## Solution

**VoiceInput**：常驻菜单栏的 macOS App。点开菜单栏图标即列出所有含输入流的音频设备（勾选标记当前系统默认输入），点击任一设备即设为系统全局默认输入。设备热插拔与默认设备变更实时刷新；内置登录自启开关；纯本地构建、ad-hoc 签名自用。

## User Stories

1. 作为用户，我希望点菜单栏图标就能看到当前所有可用的输入设备，以便不用打开系统设置逐层寻找。
2. 作为用户，我希望点击列表中任一设备即把它设为系统默认输入，以便一步完成切换。
3. 作为用户，我希望当前默认输入设备带勾选标记，以便一眼确认现在用的是哪个麦克风。
4. 作为用户，我希望插入或拔出音频设备后菜单列表自动更新，以便列表永远与真实硬件状态一致。
5. 作为用户，我希望在系统别处（如系统设置）更改默认输入后，菜单勾选自动跟随，以便勾选永远反映系统真实状态。
6. 作为用户，我希望拔掉当前默认设备后勾选自动跳到系统回落后的设备，以便明确知道现在实际在录哪个麦克风。
7. 作为用户，我希望同名设备显示为"设备名""设备名 2"，以便两个同型号麦克风也能分辨。
8. 作为用户，我希望虚拟设备（vRemoteDr 2ch、BlackHole）与物理设备一样出现在列表中，以便混音链路也能一键切换。
9. 作为用户，我希望切换蓝牙耳机的输入时不会把它拖进 HFP 单声道降级，以便听歌音质不受影响。
10. 作为用户，我希望切换失败时菜单不弹窗打扰我（勾选自然回落到真实默认），以便日常使用零打扰。
11. 作为用户，我希望列表顺序与系统设置「声音 › 输入」一致，以便两处看到的顺序相同、心智统一。
12. 作为用户，我希望菜单里有"打开声音设置…"入口，以便需要细调时快速直达。
13. 作为用户，我希望菜单里有"登录时启动"开关，以便重启后自动常驻、不想用时随时关掉。
14. 作为用户，我希望点完设备后菜单立即收起，以便符合 macOS 菜单栏 App 的使用直觉。
15. 作为用户，我希望 App 不占 Dock 图标、无主窗口，以便它安静地只活在菜单栏。
16. 作为用户，我希望设备名用系统原文（中文系统显示中文），以便与系统各处名称一致可对照。

## Implementation Decisions

- **语言与平台**：Swift 6（严格并发模式）· macOS 14.0+ · 纯 SwiftPM executable（无 .xcodeproj）。
- **音频层**：100% 原生 Core Audio HAL C API，零三方依赖（SimplyCoreAudio 已归档停更且不支持 Swift 6）。
  - 枚举：`kAudioHardwarePropertyDevices` → 逐设备查 `kAudioDevicePropertyStreams` 与 scope-input 过滤出输入设备。
  - 切换：`AudioObjectSetPropertyData` 写 `kAudioHardwarePropertyDefaultInputDevice`。
  - 监听：`kAudioHardwarePropertyDevices` + `kAudioHardwarePropertyDefaultInputDevice` 两个属性监听器，事件 50ms 防抖。
- **Swift 6 并发桥接**（已实测 0 警告 0 错误）：顶层 `nonisolated` C 函数指针作 `AudioObjectPropertyListenerProc`（不用 Block 变体，保证注销可靠）；`Unmanaged.passUnretained(self).toOpaque()` 传上下文；回调内 `Task { @MainActor in … }` 跳板；`isolated deinit`（SE-0371）注销监听。CFString 一律 `Unmanaged<CFString>?.takeRetainedValue()` 读取。
- **模块划分**（两个模块，一个接缝）：
  - `AudioDeviceManager`（`@Observable`，MainActor）：持有设备列表与默认设备 ID，负责刷新、防抖、切换动作。
  - `AudioDeviceMenuView`：独立子视图渲染菜单内容（设备列表 + 底部固定项），确保 `@Observable` 依赖注册正确、热插拔刷新。
  - **唯一测试接缝** `AudioDeviceProviding` 协议隔离 Core Audio；真实现 `CoreAudioDeviceProvider` 约 150 行。协议形状（编码自研究骨架）：
    ```swift
    protocol AudioDeviceProviding {
      func inputDevices() -> [AudioDevice]          // id + name，HAL 顺序
      func defaultInputDeviceID() -> AudioDeviceID?
      func setDefaultInputDevice(id: AudioDeviceID) -> OSStatus
      func addListener(_ handler: @escaping () -> Void) -> Bool
      func removeListener()                          // deinit 时调用
    }
    ```
- **UI**：SwiftUI `MenuBarExtra(style: .menu)`，无 `WindowGroup`；图标 SF Symbol `mic`，tooltip"输入音源"；菜单内容解耦为 `AudioDeviceMenuView`。底部固定项：打开声音设置…（`x-apple.systempreferences:com.apple.Sound-settings`）／登录时启动（toggle）／退出 VoiceInput（`NSApp.terminate(nil)`）。
- **名称与标识**：App 名 `VoiceInput`；`CFBundleIdentifier` = `com.fanbingbing.voiceinput`（反域名，SMAppService 硬要求）。
- **菜单行为规格**（0004 六项定稿）：拔出=如实反映不粘性；同名加序号永不露 UID；失败静默勾选回落；点击即收起；列表保持 HAL 返回顺序（与系统设置「声音›输入」观感一致，不按字母重排；实现时核对一次顺序一致性）。
- **进程模型**：`Info.plist` 置 `LSUIElement=true`，LaunchServices 阶段直接 `.accessory` 启动，免 Dock 闪烁。
- **开机自启**：`SMAppService.mainApp`；状态被系统关到 `.requiresApproval` 时，toggle 引导调用 `SMAppService.openSystemSettingsLoginItems()`。
- **构建与分发**：bash 脚本 `swift build -c release --show-bin-path` 动态定位产物 → 组装 `.app`（Contents/MacOS + Resources + Info.plist，`plutil -lint` 校验）→ ad-hoc `codesign --force --sign -`（.app 根，不用 `--deep`）。模板见 research/swiftpm-app-bundling.md。日常使用需安装到固定路径（`/Applications` 或 `~/Applications`）后注册自启。

## Testing Decisions

- **好测试的标准**：只测经接缝可见的外部行为（输入什么列表/默认 ID → 产出什么菜单模型），不测 Core Audio 调用细节等实现内部。
- **测试模块**：
  - `MenuModel` 纯逻辑（列表 → 菜单项）：同名去重加序号、勾选位置、HAL 顺序保持、空列表边界——直接构造数据测。
  - `AudioDeviceManager`：注入 fake `AudioDeviceProviding` 测刷新/防抖/切换失败静默回落。
- **不经自动化**：真实 HAL（会动系统全局状态）、MenuBarExtra 渲染——由下方手动验收覆盖。
- **先例**：绿地项目无先例；采用 Swift Testing（`swift test`，工具链内置）。
- **手动验收清单**（实现完成的定义）：
  1. `swift build && swift test` 全绿。
  2. 打包脚本产出可双击运行的 .app，无 Dock 图标。
  3. 菜单列表与系统设置「声音›输入」条目一致（含虚拟设备）、顺序一致。
  4. 点击切换后系统设置里默认输入同步变化；勾选跟随。
  5. 插拔 USB 设备列表即时增减；拔出默认设备后勾选自动跳到回落设备。
  6. 同名设备出现序号后缀。
  7. 登录时启动 toggle 可开可关；`.requiresApproval` 场景能引导到系统设置。
  8. 常驻半小时内存/CPU 无异常增长。

## Out of Scope

- 输出设备切换（另开新图）
- 按 App 的输入路由（HAL 插件/私有 API，已否决）
- 只读不切的纯展示形态（已否决）
- App Store / Developer ID 公证等对外分发（自用）
- Xcode 项目形态（已定 SwiftPM）
- macOS 13 及以下兼容
- 输入电平表（VU）、全局快捷键、听写 App 联动/自动切换（雾区，见地图）
- 粘性设备选择（记住手选、插回自动切回，0004 已否决）

## Further Notes

- 证据与可照抄代码骨架：`research/coreaudio-api-verification.md`（Swift 6 回调桥接完整范式）、`research/swiftpm-app-bundling.md`（bundle-app.sh 模板、Info.plist 最小内容、SMAppService 实测记录）。
- 蓝牙安全边界：只设默认输入、不创建音频流，不会主动触发 HFP/SCO 降级。
- ad-hoc 签名下 SMAppService 实测可用；CDHash 变更（重新编译覆盖安装）后注册状态保持 `.enabled`。
