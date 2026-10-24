---
id: "0026"
title: "插件接真 helper：设备列表与切换闭环"
labels: [ready-for-agent]
status: closed
claimed-by: "impl-0026"
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

## Resolution

（closed 2026-10-24）插件已跑在**真 helper** 上（`~/Applications/VoiceInput.app/Contents/MacOS/voiceinput-cli`，来自 0024 的构建），不再有任何临时桩。

**真机证据**（Raycast `Switch Audio Input`，`/tmp/vi-probe/viax` 驱动 + 独立的 HAL 探针交叉验证）：

| 验收项 | 结果 |
|---|---|
| 列表与 `voiceinput-cli list` 一致 | ✅ 8 台设备、HAL 原序、`当前` 落在默认设备 |
| 回车切换真的改变系统默认 | ✅ 177 → 209，独立探针读 HAL 亦为 209 |
| 切换耗时 | ✅ **271–290 ms** |
| HUD 出现且主窗口自动关闭 | ✅ 窗口在切换完成后关闭（`showHUD` 自带） |
| `⌘R` 跟随外部改动 | ✅ 外部改默认后 `当前` 立即移动（0021 已验，本轮回归通过） |
| 连续开关命令无旧数据 | ✅ 每个会话都重新执行 helper；`useCachedPromise` 等缓存 API 全案禁用 |
| 缺 helper → 安装空态 | ✅ 见 0027 的 A 态实测 |
| 构建与单测 | ✅ `npm run build` 通过；`vitest` 20 passed |

**路径解析实证**：`/Applications/VoiceInput.app` 存在但**没有** helper（旧版本），插件按候选顺序继续探测并落到 `~/Applications`——回退逻辑在真机上正好被这台机器验证到了。
