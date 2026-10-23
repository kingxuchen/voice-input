---
id: "0007"
title: "菜单栏骨架：真实输入设备列表"
labels: [ready-for-agent]
status: closed
claimed-by: "impl-0007"
blocked-by: []
---

## Parent

[0006 VoiceInput v1 实现规格](0006-voiceinput-v1-spec.md)

## What to build

`swift run` 后菜单栏出现 mic 图标，点开即列出本机全部含输入流的音频设备（含 vRemoteDr 等虚拟设备），名称用系统原文、保持 HAL 返回顺序，菜单底部有"退出"项。落地 SwiftPM 工程骨架（Swift 6 严格并发、macOS 14+）、`AudioDeviceProviding` 接缝（协议形状照 SPEC）与真实现 `CoreAudioDeviceProvider`、`MenuBarExtra` 菜单骨架，以及 Swift Testing 测试基建。

## Acceptance criteria

- [x] `swift build` 通过；`swift run` 后菜单栏出现 SF Symbol `mic` 图标
- [x] 菜单列出本机全部含输入流设备（含虚拟设备），名称为系统原文
- [x] 列表顺序为 HAL 返回顺序（不按字母重排）
- [x] "退出"项可正常终止进程
- [x] `swift test` 全绿：MenuModel 渲染逻辑（构造设备数据 → 菜单项名称/顺序）
- [x] `AudioDeviceProviding` 协议 + `CoreAudioDeviceProvider` 就位，桥接模式照 research 报告（nonisolated C 函数指针 + Unmanaged + Task { @MainActor }）

## Resolution

已实现（2026-10-23，impl-0007）。SwiftPM 工程骨架 + Core Audio 接缝 + MenuBarExtra 菜单全部落地。

**交付文件**

| 文件 | 职责 |
| --- | --- |
| `Sources/VoiceInputCore/AudioDeviceProviding.swift` | 唯一测试接缝协议（5 个方法，签名照 SPEC 0006） |
| `Sources/VoiceInputCore/CoreAudioDeviceProvider.swift` | Core Audio HAL 真实现（枚举/读写默认输入/属性监听） |
| `Sources/VoiceInputCore/AudioDeviceManager.swift` | `@Observable @MainActor` 管理器，持有设备列表与默认 ID |
| `Sources/VoiceInputCore/AudioDeviceMenuView.swift` | 独立子视图（`@Observable` 依赖订阅必需） |
| `Sources/VoiceInputCore/MenuModel.swift` | 纯逻辑：设备列表 → 菜单项（勾选前缀） |
| `Sources/VoiceInput/VoiceInputApp.swift` | `MenuBarExtra` + `.accessory` 激活策略 + 菜单挂载 |
| `Tests/VoiceInputCoreTests/` | 9 个测试（MenuModel / Manager / CoreAudioProvider） |

**协议与 SPEC 的一处偏差（必读）**

SPEC 0006 给的协议是非隔离的（`protocol AudioDeviceProviding { ... }`）。但 Swift 6 严格并发下
`@MainActor` 类型无法满足 nonisolated 协议需求（编译报 `#ConformanceIsolation`），而本项目
provider 必须用 `isolated deinit`（SE-0371）来可靠注销 HAL 监听器 —— 两者不可兼得。

实测三种写法（Swift 6.4）：

1. 协议非隔离 + `@MainActor` 类直接 conform → 编译失败 `#ConformanceIsolation`。
2. 协议非隔离 + `extension Impl: @MainActor P {}`（isolated conformance）→ 能编译，但
   **隔离性在 `any P` 处被静默擦除**：非隔离上下文仍可调用 `p.inputDevices()`，
   数据竞争重新变成运行期风险（编译器不再拦）。
3. **协议标注 `@MainActor`** → 编译通过，且任何非隔离调用点被编译器拒绝
   （`#ActorIsolatedCall`），隔离性由类型系统强制保证。

故采用第 3 种：**协议加 `@MainActor` 标注，方法签名逐字不变**。调用方（`AudioDeviceManager`、
全部 UI）本就都在主线程，语义零损失，且换来编译期隔离保证。SPEC 的协议体建议按此同步修订。

**留给后续票的接口预留**

- 0008：`CoreAudioDeviceProvider.addListener/removeListener` 已就位（C 函数指针桥接范式照 research 第 6 节：
  顶层 `nonisolated` 函数指针、`Unmanaged.passUnretained(self).toOpaque()`、回调内 `Task { @MainActor in … }`、
  `isolated deinit` 注销、CFString 一律 `takeRetainedValue()`）；`AudioDeviceManager.refresh()` 已预留为刷新入口，
  只需接上防抖定时器与监听回调即可。
- 0009：同名设备加序号（"X"、"X 2"）可在 `MenuModel.deviceItems` 内实现，不动 provider；
  `MenuBarExtra` 目前不提供 `tooltip` 修饰符，tooltip 需另找方案（如 `NSStatusItem` 或 label 内嵌）。
- 0011："打开声音设置…"与"登录时启动"是菜单底部固定项，插入点已在 `AudioDeviceMenuView` 的 Divider 之后；
  "退出 VoiceInput"本票已实现。

**实测记录（本机 macOS 26.6.2 arm64）**

`swift build` 零警告零错误；`swift test` 9 测试全绿。`swift run` 后菜单栏出现 SF Symbol `mic`
（AX 名称"麦克风"），点开列出 8 个输入设备，顺序与 HAL 原序一致：

```
“jwt”的麦克风 / BlackHole 16ch / BlackHole 2ch / BlackHole 64ch /
MacBook Pro麦克风 / MiRemoteV 2ch / TFFAudio / ✓  vRemoteDr 2ch
```

分隔线 + "退出 VoiceInput"（点击后进程干净退出）。点击 BlackHole 2ch 后系统默认输入确实变为
BlackHole 2ch（HAL 探针验证）、勾选跟随；已切回 vRemoteDr 2ch 恢复原状。

本票只做静态列表：设备列表在 manager 初始化时取一次；热插拔实时刷新属 0008。
