---
id: "0019"
title: "菜单打开新鲜度真机复验：确认 0013 覆盖所有陈旧来源"
labels: [wayfinder:task]
status: closed
claimed-by: "mainline-session"
blocked-by: []
---

## Parent

[0014 Raycast 音频输入切换插件 — Wayfinder 地图](0014-raycast-plugin-map.md)

## Question

主人要求「原有应用展开菜单时也要获取最新音源与当前选中」。0013 已用 `NSMenu.didBeginTrackingNotification` → `AudioDeviceManager.refresh()` 实现并做过一次探针验证（假设备注入）。本票只做**回归复验 + 判据确认**，决定是否还需要补代码：

1. 外部改默认输入（系统设置里改，或第三方工具改）→ **立刻**点开菜单，勾选是否已是新值？
2. 设备热插拔（可用已有 fake 单测覆盖，不做真实拔插——0012 已记录真实拔插风险）→ 菜单跟随？
3. 菜单**保持打开**期间系统状态变化 → 下次打开是否刷新（不做打开期间轮询，需确认这是可接受语义）？
4. 刷新耗时是否在可感知阈值内（毫秒级 HAL 同步读取，设备 8 台时的实测值）？
5. 判定：现行为是否已满足"每次打开都最新"？若否，缺口在哪、开票补。

产出：Resolution 记录 5 条实测结论 + 是否需要补代码的结论（若需要，创建新票并回链）。

## Resolution

（closed 2026-10-24。**判定：现行为已满足「每次打开都最新」，不需要补代码。** 实测环境：本机 macOS 26.6.2 arm64，已安装 `/Applications/VoiceInput.app`，8 台输入设备。）

### 1. 外部改默认 → 立刻点开菜单：**通过（已是最新）**

- 做法：HAL 探针 `/tmp/vi-probe/viprobe set <id>` 在 App 外改系统默认输入 → 立刻 AX `kAXPressAction` 点开状态栏项 → 读菜单项标题的 `✓` 前缀。
- 结果：`177 → 93`、`172 → 149`、`149 → 172` 三次切换，**每次点开都直接显示新的 ✓ 位置**，无一次停留在旧值。
- 机理：`MenuOpenObserver` 的 `didBeginTrackingNotification` 回调里同步跑 `manager.refresh()`，先于 SwiftUI 构建条目。

### 2. 设备热插拔：**由既有单测覆盖，未做真机拔插**

- `swift test`：**47 tests in 8 suites passed**（基线未变）。
- 真实拔插按 0012 的裁决继续回避（上轮用 aggregate device 测热插拔曾拆掉蓝牙采集设备的音频流）。

### 3. 菜单**保持打开**期间的系统变化：**实测会实时跟随，比预期更强**

- 做法：菜单保持展开，外部改默认输入，再 AX 读**已打开**菜单的条目。
- 结果：`TFFAudio → MiRemoteV 2ch`、`MiRemoteV 2ch → TFFAudio` 两次，**打开着的菜单勾选当场就变了**。
- 原因不是轮询：`AudioDeviceManager` 的 HAL 属性监听器（`kAudioHardwarePropertyDefaultInputDevice`）在菜单打开期间照样回调 → 50ms 防抖 → `refresh()` → `@Observable` 驱动 SwiftUI 菜单项刷新。
- 结论：不存在「打开期间说了假话」的时间窗，故「打开期间不做轮询」的语义是安全的。

### 4. 刷新耗时：**毫秒级，不可感知**

在 `AppState` 的菜单打开回调里临时插桩计时（验证后已还原，`git diff` 干净），连开 8 次菜单的日志：

```
menu-open refresh: devices+default 4.40 ms, loginItem 3.33 ms
menu-open refresh: devices+default 6.63 ms, loginItem 7.68 ms
menu-open refresh: devices+default 5.44 ms, loginItem 7.52 ms
menu-open refresh: devices+default 4.67 ms, loginItem 5.51 ms
menu-open refresh: devices+default 2.80 ms, loginItem 2.64 ms
menu-open refresh: devices+default 5.70 ms, loginItem 7.78 ms
menu-open refresh: devices+default 3.07 ms, loginItem 7.11 ms
menu-open refresh: devices+default 6.31 ms, loginItem 6.78 ms
```

- 设备+默认读取 **2.8–6.6 ms**，登录项状态 **2.6–7.8 ms**。
- 冷启动首次 HAL 枚举明显更贵（独立探针进程实测首调 **190–270 ms**，后续调用降到 **2.1 ms**）——但 App 常驻，HAL 连接一直在，菜单打开路径只走热路径。
- 因此 0013 遗留的「若设备数显著增长再评估节流」不成立：8 台设备下刷新总量 < 15 ms，无需节流。

### 5. 判定与后续

- **满足「每次打开都最新」**，无需补代码，也就不开新票。
- 顺带确认：[0017](0017-cli-contract.md) 给插件定的 `execFile` 超时 2000 ms 对**一次性 helper 进程**是合适的——那种冷启动要付 190–270 ms 的 HAL 首次枚举成本，但离 2000 ms 仍有安全余量。

### 附：本票产生的可复用探针（未入库，`/tmp/vi-probe/`）

- `viprobe list|default|set <id>`：纯 Core Audio HAL 读写探针（≈50 行），用于在 App 之外改/读系统默认输入。
- `vifresh2 <pid> timing|stayopen <id>`：AX 驱动状态栏项点开并读菜单项标题/`✓` 标记，测「点开→渲染」时延与打开期间跟随。
- 后续做 [0021](0021-raycast-skeleton-prototype.md) 或 CLI 真机验证时可直接复用。
