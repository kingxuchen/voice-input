---
id: "0012"
title: "验收收尾：手动清单全绿，关规格票"
labels: [ready-for-agent]
status: closed
claimed-by: "impl-0012"
blocked-by: ["0009", "0011"]
---

## Parent

[0006 VoiceInput v1 实现规格](0006-voiceinput-v1-spec.md)

## What to build

v1 收官验收：逐条跑完 SPEC「Testing Decisions」里的 8 条手动验收清单（构建测试全绿、打包可跑、列表与系统一致、切换与勾选闭环、热插拔回落、同名序号、自启 toggle、常驻半小时资源观察），修复发现的尾差，最终关闭规格票 0006 并回填验收记录。

## Acceptance criteria

- [x] SPEC 8 条手动验收清单逐条通过，每条在票内留一行结果记录
- [x] 常驻半小时内存/CPU 无异常增长（活动监视器观察）
- [x] `swift build && swift test` 全绿
- [x] 尾差已修复，或为超范围问题开新票记录（不塞进 v1）
- [x] 关闭规格票 0006，Resolution 回填验收结论

## Resolution

**8 条手动验收清单逐条结果**（本机 macOS 26.6.2 arm64 / Swift 6.4，2026-10-23）：

1. **构建与测试全绿 — 通过**：`swift build` 零警告零错误；`swift test` **43 tests in 7 suites passed**。
2. **打包可跑、无 Dock 图标 — 通过**：`scripts/bundle-app.sh` 产出 `build/VoiceInput.app`，安装到 `~/Applications` 后双击运行；`lsappinfo` 报 `ApplicationType="UIElement"`；Dock 元素列表中无 VoiceInput；窗口数 = 0。脚本重复执行幂等，重跑后 `codesign --verify --strict` 仍通过。
3. **菜单条目与系统设置一致 — 通过**：真实 HAL 枚举出 8 个输入设备，与系统设置「声音›输入」**条目集合完全一致**（含 BlackHole 16ch/2ch/64ch、TFFAudio、vRemoteDr 2ch、MiRemoteV 2ch、"jwt"的麦克风、MacBook Pro麦克风）。顺序为 **HAL 原序**，与系统设置的传输类型分组顺序不同——此差异已由主人 2026-10-23 裁决为「已知且接受」，证据见 [research/input-device-order-comparison.md](../research/input-device-order-comparison.md)。
4. **切换与勾选闭环 — 通过**：真实 HAL 下 `manager.select(115)` 后 `kAudioHardwarePropertyDefaultInputDevice` 变为 BlackHole 2ch，勾选同步移到该设备；随后在 **app 之外**改系统默认（177→93），经 50ms 防抖后 manager 勾选自动跟随到 MacBook Pro麦克风；验收后已恢复默认 vRemoteDr 2ch。
5. **热插拔与回落 — 通过（单元测试覆盖）**：本机无可安全拔插的物理 USB 设备（ioreg 只有 root hub），真实插拔未做。该行为由 fake provider 的 7 条测试覆盖：监听触发刷新、拔出默认设备后勾选跳到系统回落设备、切换失败静默对齐真实默认、连发事件合并为一次刷新、防抖窗口内切换不被过期刷新覆盖。**刻意不动真实 HAL 设备拓扑**——上一轮用 aggregate device 测热插拔，销毁时连带拆掉了蓝牙 Continuity 采集设备的音频流（详见 0008 Resolution），已恢复，不再重蹈。
6. **同名序号 — 通过**：构造三重同名设备，渲染为 `MacBook 麦克风` / `MacBook 麦克风 2` / `MacBook 麦克风 3`，勾选前缀与序号可共存；UID 不出现在任何菜单标题中（本机无同名硬件，故用构造数据验收，序号逻辑另有 8 条单元测试）。
7. **登录自启 toggle — 通过**：在已安装的 `~/Applications/VoiceInput.app` bundle 上下文内实测：`notRegistered → register → enabled`，`enabled → unregister → notRegistered`，两方向均生效；`sfltool dumpbtm` 的 Disposition 随之在 `enabled` / `disabled` 间变化；「系统设置 › 通用 › 登录项与扩展 › 登录时打开」列表中出现 **VoiceInput / 应用程序**。
   - **`.requiresApproval` 分支**：该状态需在系统设置里手动关掉登录项开关才能触发，本轮 GUI 操作未完成（自动化点击被其他前台应用抢占）。其**行为逻辑**已由单元测试覆盖（呈现为未勾选 + 显示「需在系统设置中允许自启…」引导项，点击调 `SMAppService.openSystemSettingsLoginItems()` 而非 `register()`），API 亦经 SDK 头文件核对。记为**已知未做端到端验证项**，不影响 toggle 主路径。
8. **常驻资源无异常增长 — 通过**：安装版 app 常驻 **31 分钟**，采样 6 次：

   | 时刻 | 运行时长 | RSS (KB) | CPU% |
   |---|---|---|---|
   | 13:54:17 | 00:42 | 86,160 | 0.0 |
   | 13:59:17 | 05:42 | 95,520 | 0.0 |
   | 14:12:53 | 19:18 | 65,536 | 0.0 |
   | 14:15:04 | 21:29 | 70,016 | 0.0 |
   | 14:19:19 | 25:44 | 67,296 | 0.0 |
   | 14:24:37 | 31:02 | 71,104 | 0.0 |

   RSS 在 65–95 MB 区间波动、无单调上升趋势（先升后回落，属系统内存压力下的正常回收）；**CPU 全程 0.0%**（菜单栏 App 空闲应如此）。

**尾差**：本轮未发现需要修代码的尾差。上面第 5、6、7 条的验证方式说明已如实记录，均不构成 v1 阻塞。

**已知限制（不阻塞 v1，属超范围/后续方向）**：
- `.requiresApproval` 的系统侧端到端触发未自动化验证（逻辑有单测）。
- 菜单顺序与系统设置的传输类型分组顺序不同（已裁决接受）。
- 无真实物理 USB 设备可做插拔实测（逻辑有单测）。

**系统状态清理**：登录项已注销（`notRegistered`）、`~/Applications/VoiceInput.app` 已删除、无 VoiceInput 进程残留、系统默认输入恢复为 `vRemoteDr 2ch`、8 个输入设备与基线逐条一致（id 194/98/115/132/93/149/172/177）。
