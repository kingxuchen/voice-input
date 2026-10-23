---
id: "0008"
title: "核心闭环：点击切换默认输入 + 实时跟随"
labels: [ready-for-agent]
status: open
claimed-by: ""
blocked-by: ["0007"]
---

## Parent

[0006 VoiceInput v1 实现规格](0006-voiceinput-v1-spec.md)

## What to build

完整可用的切换闭环：点击菜单中任一设备即设为系统全局默认输入（系统设置同步变化）；当前默认带勾选标记；设备热插拔与默认变更时菜单即时刷新（50ms 防抖）；拔出当前默认设备后勾选自动跳到系统回落设备；切换失败静默（勾选始终对齐真实默认）。实现属性监听器（设备列表 + 默认输入两项）与 `AudioDeviceManager` 刷新逻辑。

## Acceptance criteria

- [ ] 点击设备后，系统设置「声音›输入」的默认设备同步变为所点设备
- [ ] 当前默认设备带勾选；在系统别处改默认后，勾选自动跟随
- [ ] 插拔设备列表即时增减；拔出当前默认设备后，勾选自动跳到回落设备
- [ ] 切换失败（如设备刚拔出）无弹窗无崩溃，勾选对齐真实默认
- [ ] 事件防抖：热插拔/蓝牙握手连发事件时菜单不抖动
- [ ] `swift test` 全绿：fake `AudioDeviceProviding` 驱动 `AudioDeviceManager`（列表刷新、防抖、切换失败回落）+ 勾选逻辑
