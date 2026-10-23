---
id: "0008"
title: "核心闭环：点击切换默认输入 + 实时跟随"
labels: [ready-for-agent]
status: closed
claimed-by: "impl-0008"
blocked-by: ["0007"]
---

## Parent

[0006 VoiceInput v1 实现规格](0006-voiceinput-v1-spec.md)

## What to build

完整可用的切换闭环：点击菜单中任一设备即设为系统全局默认输入（系统设置同步变化）；当前默认带勾选标记；设备热插拔与默认变更时菜单即时刷新（50ms 防抖）；拔出当前默认设备后勾选自动跳到系统回落设备；切换失败静默（勾选始终对齐真实默认）。实现属性监听器（设备列表 + 默认输入两项）与 `AudioDeviceManager` 刷新逻辑。

## Acceptance criteria

- [x] 点击设备后，系统设置「声音›输入」的默认设备同步变为所点设备
- [x] 当前默认设备带勾选；在系统别处改默认后，勾选自动跟随
- [x] 插拔设备列表即时增减；拔出当前默认设备后，勾选自动跳到回落设备
- [x] 切换失败（如设备刚拔出）无弹窗无崩溃，勾选对齐真实默认
- [x] 事件防抖：热插拔/蓝牙握手连发事件时菜单不抖动
- [x] `swift test` 全绿：fake `AudioDeviceProviding` 驱动 `AudioDeviceManager`（列表刷新、防抖、切换失败回落）+ 勾选逻辑

## Resolution

- **切换闭环**：`AudioDeviceManager.select(deviceID:)` 调 `provider.setDefaultInputDevice(id:)`，**无论成败都重新读 `provider.defaultInputDeviceID()`** 回填 `defaultDeviceID`——这是「切换失败静默、勾选始终对齐真实默认」的实现方式：失败时 `OSStatus` 被丢弃，勾选自然回落到系统真实默认，不弹窗不通知。
- **监听与防抖**：`AudioDeviceManager.init` 里 `provider.addListener { [weak self] in Task { @MainActor in self?.scheduleRefresh() } }` 注册回调；`scheduleRefresh()` 取消上一个 `Task` 并 `Task.sleep(for: debounceInterval)`（默认 50ms）后调 `refresh()`，实现"连发事件只刷一次"。
- **防抖间隔可注入**：`init(provider:debounceInterval:)`，默认 `.milliseconds(50)`。测试用更大的间隔（如 300ms）以避免时序抖动，是为了让断言稳定而非改变生产行为。
- **生命周期**：`isolated deinit` 里 `refreshTask?.cancel()` + `provider.removeListener()`，确保离开 MainActor 域的注销可靠、监听器成对解除（无野指针）。
- **"过期刷新不覆盖新选择"**：`select()` 后若还有防抖任务在飞，刷新读的是系统真实默认（即刚选中的那个），因此不会被旧数据盖掉——已由测试 `pendingRefreshDoesNotOverrideFreshSelection` 固定。
- **实机验证**（本机真实 HAL）：
  - 监听器确实触发：创建真实 aggregate 输入设备后，`kAudioHardwarePropertyDevices` 监听器被触发，manager 列表从 9 台增至 10 台，新设备出现在菜单。
  - 拔出默认设备端到端：把 aggregate 设为默认后销毁它 → 菜单移除该条目、勾选**自动跳到系统回落设备**（vRemoteDr 2ch）。
  - 防抖量化：连发 20 个事件 → 只触发 1 次刷新；事件间隔 100ms → 触发 2 次（不会被错误合并）。
  - 监听器注销：manager 释放后 `provider.removeListener()` 生效，无残留监听。
- **测试**：`swift build` 零警告零错误；`swift test` 16 tests in 4 suites passed（本票新增 7 条：监听刷新、防抖窗口、连发合并、系统别处改默认后跟随、拔除默认后回落、切换失败静默、防抖窗口内切换不被过期刷新覆盖）。
- **已知副作用与恢复**：验证"拔出默认设备"时用了 aggregate device，销毁它连带拆掉了 Bluetooth Continuity 采集设备（"jwt"的麦克风，id 194）的音频流，系统对其置了「User Disconnect」抑制标记。已恢复：`IOBluetoothDevice.openConnection()` 恢复蓝牙连接 → `kill` ContinuityCaptureAgent 进程（launchd 自动重启）→ 设备随即重新注册为输入设备，**id 与 uid 与基线一致**，默认输入仍为 vRemoteDr 2ch。后续如需再测热插拔，应改用 fake provider（单元测试已覆盖），不要再动真实设备拓扑。
