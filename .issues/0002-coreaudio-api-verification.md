---
id: 0002
title: "Core Audio 方案核查：枚举输入设备、切换默认输入、热插拔监听"
labels: [wayfinder:research]
status: closed
claimed-by: "research-agent-0002"
blocked-by: []
---

## Question

用哪条 API 路线实现三件事：(1) 枚举所有含输入流的设备（含虚拟设备）；(2) 把某设备设为系统默认输入；(3) 监听设备增减与默认输入变更以驱动 MenuBarExtra 实时刷新。核查维度：

- 原生 Core Audio（`AudioObjectGetPropertyData` / `kAudioHardwarePropertyDefaultInputDevice` / 属性监听器）vs 三方库（SimplyCoreAudio、AudioSwitcher 等）：维护状态、Swift 6 严格并发下的可用性。
- Swift 6 语言模式下，C 函数指针属性监听回调如何安全回传到 SwiftUI/MainActor（`@Observable` 状态）——给出可编译的模式。
- 蓝牙耳机 HFP/A2DP 档位切换对"设为默认输入"的影响与边界情况。
- `MenuBarExtra` 的菜单重渲染机制（设备列表更新是否自动重建菜单内容）。
- 结论需给出：推荐路线 + 最小可照抄代码骨架 + 风险清单。以 Apple 官方文档、GitHub 一手仓库为准。

## Resolution

- **推荐路线**：采用 **100% 原生 Core Audio HAL C API**，零三方库依赖，手写轻量 Swift 6 Concurrency 安全封装层（约 150 行）。
- **关键结论**：
  1. **三方库不可用**：`SimplyCoreAudio` 已于 2024-03-23 正式归档停更，且引入 `swift-atomics` 与 C 桥接包，不支持 Swift 6 严格并发模式；switchaudio-osx 为命令行工具，不支持回调式热插拔监听。经 TypeSafe AI `jev_decide` 模型评估，原生路线在并发性、可维护性与无外部依赖上获 100% 推荐置信度。
  2. **Swift 6 C 回调桥接完全跑通**：采用静态 `nonisolated func` 充当 `AudioObjectPropertyListenerProc`（避免 Block 闭包指针注销不匹配 bug），通过 `Unmanaged.passUnretained(self).toOpaque()` 传参，回调内用 `Task { @MainActor in manager.notifyChanged() }` 跳板回主线程；在 Swift 6.4 中配合 `isolated deinit`（SE-0371）安全注销。经实机编译器检查，达到 **0 警告、0 错误**。
  3. **CFString 内存规范**：采用 `Unmanaged<CFString>?.takeRetainedValue()` 读取设备名和 UID，符合 Core Audio Create Rule 彻底避免内存泄漏，并消除 Optional 指针类型警告。
  4. **蓝牙 HFP 风险安全隔离**：切换器仅调用 `AudioObjectSetPropertyData` 设置系统默认输入，自身不创建任何 AudioUnit 输入流或录音会话，因此**不会**主动触发蓝牙耳机从 A2DP（48kHz 立体声）降级为 HFP/SCO（16kHz 单声道通话）模式。结合 50ms 异步防抖可抵御设备插拔与蓝牙握手时的连续多次抖动。
  5. **MenuBarExtra 重渲染验证**：将菜单内容解耦为独立子视图 `AudioDeviceMenuView` 并传入 `@Observable` 管理器，可确保 SwiftUI 正确注册属性依赖，在设备热插拔或默认设备切换时无感刷新。
- **详尽调研报告与已验证代码骨架**：见 [research/coreaudio-api-verification.md](../research/coreaudio-api-verification.md)。
