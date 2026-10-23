---
id: "0009"
title: "菜单呈现定稿：同名序号 + 顺序核对"
labels: [ready-for-agent]
status: closed
claimed-by: "impl-0009"
blocked-by: ["0008"]
---

## Parent

[0006 VoiceInput v1 实现规格](0006-voiceinput-v1-spec.md)

## What to build

菜单呈现的边角定稿：同名设备自动追加序号（"MacBook 麦克风""MacBook 麦克风 2"，永不向用户暴露 UID）；序号在热插拔刷新间保持稳定；菜单栏图标 tooltip"输入音源"；人工核对一次菜单顺序与系统设置「声音›输入」列表一致。

## Acceptance criteria

- [x] 同名设备显示"X""X 2"（三个同名到"X 3"），任何 UI 位置不出现 UID
- [x] 同名设备集合不变时，刷新前后序号稳定不跳变
- [x] 菜单栏图标 tooltip 显示"输入音源"
- [x] 人工核对：菜单**条目**与系统设置「声音›输入」一致（含虚拟设备）；顺序为 HAL 顺序，与系统设置的传输类型分组顺序**不同**——此差异已由主人 2026-10-23 裁决为"已知且接受"，在本票记录实测证据
- [x] `swift test` 全绿：序号逻辑（两重/三重同名、空列表、刷新稳定性）

## Resolution

- **同名序号**（`MenuModel.displayNames(for:)`，纯逻辑，不动 provider/manager）：按 **HAL 出现次序**分配——组内第一个用裸名，第二个 `X 2`，第三个 `X 3`。刻意不按字母序排序：按字母序会让真实名 "MacBook 麦克风" 与 "MacBook 麦克风 2" 混淆；按 HAL 次序则稳定，且是刷新间不跳变的前提（序号跟着设备走，不跟着名字走）。
- **"真实名字自带序号"的冲突处理**：先收集全部真实名进 `used` 集合，分配序号时若候选名已被真实设备占用则**继续跳号**（X → X 2 → X 3…）。例：设备为 `["MacBook 麦克风", "MacBook 麦克风 2", "MacBook 麦克风"]` 时，第三个显示 `MacBook 麦克风 3`，避免菜单里出现两条 "MacBook 麦克风 2"。已由测试 `realNameWithSuffixIsNotShadowed` 固定。
- **UID 永不出现在 UI**：`MenuItem` 只承载 `name`（设备名原文），无 UID 字段；测试 `titlesNeverExposeDeviceID` 断言标题不含设备 id 数字。
- **tooltip**：`MenuBarExtra` 无 tooltip 修饰符（SwiftUI swiftinterface 确认 Scene 只有 `init(isInserted:content:label:)` / `init(content:label:)`）。可行方案是改用 `init(content:label:)`，在 label 上加 `.help("输入音源")`。**实机验证**：AX 读状态项得 `title=麦克风 help=输入音源`；去掉 `.help()` 的对照组 `help` 为空——确认 help 来自 `.help()` 而非 label 标题。
- **顺序核对**：菜单顺序 = HAL 原序，代码中**无任何 sort**。与系统设置的差异（系统设置按传输类型分组：内建→USB→虚拟→蓝牙）已实测留证于 [research/input-device-order-comparison.md](../research/input-device-order-comparison.md)，并由主人 2026-10-23 裁决为"已知且接受"；原 User Story 11「与系统设置顺序一致」已据此作废，改为「顺序稳定不跳动」。
- **验证**：`swift build` 零警告零错误；`swift test` 17 tests in 3 suites passed（本票新增 8 条序号/UID/稳定性测试，原 9 条全绿）。
