---
id: "0009"
title: "菜单呈现定稿：同名序号 + 顺序核对"
labels: [ready-for-agent]
status: open
claimed-by: ""
blocked-by: ["0008"]
---

## Parent

[0006 VoiceInput v1 实现规格](0006-voiceinput-v1-spec.md)

## What to build

菜单呈现的边角定稿：同名设备自动追加序号（"MacBook 麦克风""MacBook 麦克风 2"，永不向用户暴露 UID）；序号在热插拔刷新间保持稳定；菜单栏图标 tooltip"输入音源"；人工核对一次菜单顺序与系统设置「声音›输入」列表一致。

## Acceptance criteria

- [ ] 同名设备显示"X""X 2"（三个同名到"X 3"），任何 UI 位置不出现 UID
- [ ] 同名设备集合不变时，刷新前后序号稳定不跳变
- [ ] 菜单栏图标 tooltip 显示"输入音源"
- [ ] 人工核对：菜单顺序与系统设置「声音›输入」一致；若不一致，在本票记录差异与处理决定
- [ ] `swift test` 全绿：序号逻辑（两重/三重同名、空列表、刷新稳定性）
