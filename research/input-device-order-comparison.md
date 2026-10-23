# 输入设备顺序实测：HAL 顺序 vs 系统设置「声音 › 输入」顺序

- **关联票**：0009（菜单呈现定稿）· 0006（实现规格）
- **实测日期**：2026-10-23
- **环境**：macOS 26.6.2 (Darwin 25G83, arm64)，Swift 6.4

## 结论

**菜单保持 HAL 顺序（`kAudioHardwarePropertyDevices` 原序），不模仿系统设置的分组排序。**

这是主人 2026-10-23 的裁决。原 SPEC User Story 11「列表顺序与系统设置「声音 › 输入」一致」据此作废，改为「顺序稳定不跳动」。

## 为什么两者不一致

系统设置「声音 › 输入」列表**按设备传输类型分组**，组内保持相对顺序；HAL 返回的是混合顺序。分组依据是 `kAudioDevicePropertyTransportType`，其值是 FourCC（如 `bltn` / `usb ` / `virt` / `ccwd`），**没有稳定的数值序**，因此"内建→USB→虚拟→蓝牙"这套次序是系统内部私有规则，无法用公开 API 复现。强行按类型排序会对未知传输类型（AirPlay / HDMI / PCI / MIDI 等）错排。

而 HAL 顺序本身稳定，且是同名序号分配逻辑（0009）的输入前提——序号必须建立在稳定的输入顺序上。

## 实测数据（本机 8 个输入设备）

HAL 顺序（`kAudioHardwarePropertyDevices` 原序）：

| # | 设备名 | transport FourCC | 系统设置显示类型 |
|---|---|---|---|
| 1 | “jwt”的麦克风 | `ccwd` | 连续互通相机 |
| 2 | BlackHole 16ch | `virt` | 虚拟 |
| 3 | BlackHole 2ch | `virt` | 虚拟 |
| 4 | BlackHole 64ch | `virt` | 虚拟 |
| 5 | MacBook Pro麦克风 | `bltn` | 内建 |
| 6 | MiRemoteV 2ch | `usb ` | USB |
| 7 | TFFAudio | `virt` | 虚拟 |
| 8 | vRemoteDr 2ch | `usb ` | USB |

系统设置「输入」顺序：

| # | 设备名 | 类型 |
|---|---|---|
| 1 | MacBook Pro麦克风 | 内建 |
| 2 | MiRemoteV 2ch | USB |
| 3 | vRemoteDr 2ch | USB |
| 4 | BlackHole 16ch | 虚拟 |
| 5 | BlackHole 2ch | 虚拟 |
| 6 | BlackHole 64ch | 虚拟 |
| 7 | TFFAudio | 虚拟 |
| 8 | “jwt”的麦克风 | 连续互通相机 |

规律：系统设置 = 内建 → USB → 虚拟 → 蓝牙（连续互通相机），**组内**保持 HAL 相对顺序。

> 附注：系统设置把蓝牙耳机归类为「连续互通相机」而非「蓝牙」，这个显示文案来自系统私有映射，无法用公开 API 直接取得。

## 复现方法

HAL 顺序与 transport 值：

```swift
// 枚举 kAudioHardwarePropertyDevices → 逐个查 kAudioDevicePropertyStreams（scope=input）过滤
// 再查 kAudioDevicePropertyTransportType（UInt32）→ 转 FourCC 便于阅读
```

系统设置顺序：用 Accessibility API 读 System Settings 进程（bundle id `com.apple.systempreferences`）窗口内的 `AXStaticText` 列表，顺序即显示顺序。

## 给实现者的注意

- 菜单项顺序 = HAL 顺序 = `CoreAudioDeviceProvider.inputDevices()` 的返回顺序。**不要**加任何 sort。
- 同名序号（0009）必须基于同一份 HAL 顺序分配，刷新间保持稳定。
- 验收时对照的是**条目集合**（设备名一致、都含虚拟设备），不是顺序。
