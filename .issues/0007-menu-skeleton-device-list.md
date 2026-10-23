---
id: "0007"
title: "菜单栏骨架：真实输入设备列表"
labels: [ready-for-agent]
status: open
claimed-by: ""
blocked-by: []
---

## Parent

[0006 VoiceInput v1 实现规格](0006-voiceinput-v1-spec.md)

## What to build

`swift run` 后菜单栏出现 mic 图标，点开即列出本机全部含输入流的音频设备（含 vRemoteDr 等虚拟设备），名称用系统原文、保持 HAL 返回顺序，菜单底部有"退出"项。落地 SwiftPM 工程骨架（Swift 6 严格并发、macOS 14+）、`AudioDeviceProviding` 接缝（协议形状照 SPEC）与真实现 `CoreAudioDeviceProvider`、`MenuBarExtra` 菜单骨架，以及 Swift Testing 测试基建。

## Acceptance criteria

- [ ] `swift build` 通过；`swift run` 后菜单栏出现 SF Symbol `mic` 图标
- [ ] 菜单列出本机全部含输入流设备（含虚拟设备），名称为系统原文
- [ ] 列表顺序为 HAL 返回顺序（不按字母重排）
- [ ] "退出"项可正常终止进程
- [ ] `swift test` 全绿：MenuModel 渲染逻辑（构造设备数据 → 菜单项名称/顺序）
- [ ] `AudioDeviceProviding` 协议 + `CoreAudioDeviceProvider` 就位，桥接模式照 research 报告（nonisolated C 函数指针 + Unmanaged + Task { @MainActor }）
