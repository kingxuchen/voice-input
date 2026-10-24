---
id: "0013"
title: "菜单每次打开都实时获取最新音源"
labels: [ready-for-agent]
status: closed
claimed-by: "impl-0013"
blocked-by: []
---

## Parent

[0006 VoiceInput v1 实现规格](0006-voiceinput-v1-spec.md)

## What to build

主人诉求：「我每次点击菜单的时候，都实时获取最新的音频来源，能及时更新到最新的」。

v1 已有两条刷新路径（Core Audio 属性监听器 + 50ms 防抖）覆盖「热插拔 / 系统别处改默认设备」，但**没有覆盖「菜单打开那一刻重新读一次系统」**：设备列表在 App 启动时读一次，此后只靠监听器事件。实测存在缺口——监听器未触发的窗口内（外部改默认设备、监听注册失败等），菜单会显示过期状态。

同时发现 v1 的一处**行为与注释不符**：`AudioDeviceMenuView.onAppear` 注释写「菜单每次打开都重读一次系统真实登录项状态」，但真机 AX 实测 `onAppear` **只在首次打开时触发一次**（SwiftUI 复用菜单视图，不再重新 appear）。即 0011 票声称的「每次打开都回显真实状态」实际只生效一次——本次一并修正。

## Acceptance criteria

- [x] 每次点开状态栏菜单，都重新读取系统真实设备列表与当前默认输入设备
- [x] 同一路径也重新读取系统真实登录项状态（修掉 `onAppear` 只触发一次的缺口）
- [x] 刷新发生在菜单条目构建之前，本次打开即展示最新状态
- [x] 系统菜单（Apple 菜单 / App 菜单树）被排除，不会误触发刷新
- [x] `swift build` 零警告零错误；`swift test` 全绿
- [x] 真机验证：点开菜单后菜单条目包含「仅在第 2 次及以后 HAL 读取才注入」的真设备，证明打开菜单那一刻确实重读了 HAL
- [x] 既有行为无回归（热插拔跟随、默认设备跟随、切换静默、同名序号均保持）

## Resolution

- **触发点**：`NSMenu.didBeginTrackingNotification`（新文件 `Sources/VoiceInputCore/MenuOpenObserver.swift`）。
  - 为什么不用 `onAppear`：真机 AX 实证它**只在首次打开触发一次**，代表不了「每次点开菜单」；v1 依赖它的登录项刷新实际只生效一次。
  - 为什么这个通知来得及：`queue: nil` 注册 → 回调在主线程**同步**执行；AX 实测通知到达时 SwiftUI 生成的 `SwiftUIMenu` 的 `items` 数组**仍为空**，即通知早于 SwiftUI 用当前状态构建菜单条目 → 本次打开即可见最新状态。
  - 排除主菜单树：`NSApp.mainMenu` 的各级子菜单（Apple 菜单 / App 菜单）跟踪时发同一通知，按身份排除，否则点系统菜单也触发刷新。
  - Swift 6 并发：`NSMenu` 不可跨并发域传递，回调里只把 `ObjectIdentifier`（Sendable）带进主 actor；`NSApp.mainMenu` 只在主 actor 内读取。
- **编排**：新文件 `Sources/VoiceInputCore/AppState.swift` 持有 `AudioDeviceManager` + `LaunchAtLoginController`，并把「菜单打开了」翻译成「重读系统真实状态」：
  ```swift
  manager.refresh()        // 设备列表 + 当前默认输入
  launchAtLogin.refresh()  // 系统真实登录项状态
  ```
  `VoiceInputApp` 改为持有 `@State private var state = AppState(provider:launchAtLoginService:)`，菜单视图从 `state.manager` / `state.launchAtLogin` 取值。
- **删除** `AudioDeviceMenuView.onAppear`（含那句与实际行为不符的注释）——登录项刷新已由菜单打开信号统一承担，不再有两条路径。
- **测试**（`Tests/VoiceInputCoreTests/MenuOpenRefreshTests.swift`，3 条）：
  - 菜单打开 → 设备列表与默认设备被重新拉取；
  - 菜单打开 → 登录项状态被重新读取（外部改动后立即反映）；
  - 主菜单树的菜单 → 不触发刷新。
  测试注入独立 `NotificationCenter` 与 `mainMenuProvider`，不碰真实系统状态。
- **真机验证**（本机 macOS 26.6.2 arm64 / Swift 6.4）：
  - 临时在 `CoreAudioDeviceProvider` 注入探针：只有第 2 次及以后的 `inputDevices()` 读取才追加一台假设备 `PROBE-DEVICE`。
  - 启动后点开状态栏菜单，AX 读到的菜单条目**包含 `PROBE-DEVICE`** → 证明打开菜单那一刻确实重读了 HAL，且新数据进入了本次渲染的条目。
  - 连续开关菜单 3 轮，条目均正常刷新、无崩溃；移除探针后重跑，菜单列出本机 8 台真实输入设备、勾选落在 `vRemoteDr 2ch`。
  - 探针代码（假设备注入、stderr 日志）验证后已全部移除，`git diff` 只剩生产代码。
- **构建与测试**：`swift build` 零警告零错误；`swift test` **47 tests in 8 suites passed**（改动前基线 44 tests in 7 suites，新增 3 条）。
- **文档**：research/coreaudio-api-verification.md 第 5 节补记「菜单打开触发点」实测结论（`onAppear` 只触发一次、`didBeginTracking` 的时序与排除主菜单树的做法）。

## 遗留

- 菜单打开时的刷新走同步 HAL 读取（`inputDevices()` + `defaultInputDeviceID()`），单次耗时在毫秒级；若日后设备数量显著增长，可评估是否需要节流。
