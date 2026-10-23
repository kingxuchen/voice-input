---
id: 0002
title: "Core Audio 方案核查：枚举输入设备、切换默认输入、热插拔监听"
labels: [wayfinder:research]
status: open
claimed-by: ""
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

（待研究 session 填写）
