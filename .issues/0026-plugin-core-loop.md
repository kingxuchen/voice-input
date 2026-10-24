---
id: "0026"
title: "插件接真 helper：设备列表与切换闭环"
labels: [ready-for-agent]
status: open
claimed-by: ""
blocked-by: ["0024"]
---

## Parent

[0023 VoiceInput CLI 契约 + Raycast 插件规格](0023-voiceinput-raycast-spec.md)（§C 插件规格）

## What to build

把 `raycast/` 里已经跑通的原型**转正**：它调用的是仓库产品的 helper，而不是任何临时桩。用户在 Raycast 敲命令 → 看到本机全部输入设备 → 回车就用上那支麦克风，全程悬空零点击。

- 设备来源：命令启动即调 helper 现读，`⌘R` 再读一次；不带任何跨运行缓存。
- 列表：主标题是用户可见设备名（含同名序号），当前默认项带「当前」标记；顺序与 `voiceinput-cli list` 一致。
- 切换：回车 → 调 helper 写默认输入 → 用返回的回读状态刷新列表 → HUD 报「已切换到 X」，主窗口自动关闭。
- helper 定位：偏好设置里的自定义路径优先，留空则自动探测标准安装位置。

## Acceptance criteria

- [ ] 插件不再引用任何临时/桩 helper，路径解析只指向真实安装点
- [ ] 列表与 `voiceinput-cli list` 逐条一致（设备集合、顺序、`当前` 标记）
- [ ] 回车后系统默认输入**真的改变**（用独立探针读 HAL 佐证，不只看 UI）
- [ ] 切换后 HUD 出现且主窗口自动关闭，无需额外关闭调用
- [ ] `⌘R` 能把外部刚改过的默认输入刷进列表
- [ ] 连续开关命令 5 次，界面不出现上一次的旧设备状态
- [ ] 缺少 helper 时进入安装空态，不崩溃、不显示伪造列表
- [ ] `npm run build` 通过、单测全绿

## Blocked by

- [helper CLI 落地：voiceinput-cli 三命令与打包签名](0024-helper-cli.md)
