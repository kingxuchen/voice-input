---
id: 0004
title: "行为规格定稿：菜单交互与边界行为"
labels: [wayfinder:grilling]
status: closed
claimed-by: "mainline-session"
blocked-by: []
---

## Question

与主人 grilling 定稿 v1 行为规格的边角（结合 0002 核查出的边界事实）：

- 当前默认设备被拔出后菜单如何表现（自动回落到别的设备？显示禁用项？）
- 同名设备如何区分（加 UID 尾号？设备类型标注？）
- 切换失败时的反馈方式（静默？系统通知？菜单内标记？）
- App 名称与菜单文案（中文/英文，菜单栏图标选哪个 SF Symbol）
- 点击切换后菜单收起还是保持展开

产出：SPEC 的"行为规格"一节要点。

## Resolution

六项定稿（2026-10-23，与主人 grilling 确认）：

1. **拔出当前默认设备 = 如实反映**：设备拔出即从列表消失，勾选自动跳到系统回落后的真实默认设备（属性监听器驱动，零额外代码）。不做"记住手选、插回自动切回"的粘性恢复（主力设备 vRemoteDr 为虚拟设备常驻，粘性收益小）。
2. **同名设备 = 追加序号后缀**："MacBook 麦克风"、"MacBook 麦克风 2"；永不向用户暴露 UID。
3. **切换失败 = 静默**：无弹窗、无通知；勾选始终由监听器对齐系统真实默认，"点了没勾上"本身即失败可见。v1 不做错误弹窗。
4. **名称/文案**：App 名 **VoiceInput**，bundle id `com.fanbingbing.voiceinput`；菜单栏图标 SF Symbol **`mic`**，tooltip"输入音源"；设备条目用系统设备名原文（中文系统自然显示中文）；底部固定项：**打开声音设置… ／ 登录时启动（toggle）／ 退出 VoiceInput**。
5. **点击设备后菜单立即收起**：`MenuBarExtra(style: .menu)` 系统默认行为。
6. **列表排序 = 跟随系统设置「声音 › 输入」观感**：保持 `kAudioHardwarePropertyDevices` 返回顺序（HAL 顺序）渲染，不按字母重排（主人指定；实现蓝图票核对 HAL 顺序与系统设置显示的一致性）。
