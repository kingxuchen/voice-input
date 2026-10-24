---
id: "0022"
title: "汇总定稿：CLI 契约 + Raycast 插件规格（SPEC）"
labels: [wayfinder:grilling]
status: closed
claimed-by: "mainline-session"
blocked-by: ["0017", "0018", "0019", "0020", "0021"]
---

## Parent

[0014 Raycast 音频输入切换插件 — Wayfinder 地图](0014-raycast-plugin-map.md)

## Question

按旧图 [0006](0006-voiceinput-v1-spec.md) 的 SPEC 体例，汇总前序结论为一份可照做的规格，交主人确认后关图：

1. **Problem / Solution**：Raycast 里一步切换输入音源；伴侣 App 提供 CLI。
2. **接口契约**（逐字可抄）：命令面、JSON schema、退出码与错误码、版本握手、helper 路径与打包位置、超时。
3. **插件规格**：`raycast/` 工程结构、**单条 `view`/List 命令**与动作、文案原文（中英）、空态/错误态、偏好设置、i18n 落地、Store 元数据与发布流程、禁止缓存的硬约束（细则已在 [0018 Resolution](0018-raycast-plugin-ux-store-spec.md)）。
4. **测试与验收**：Swift 单测清单（JSON 形状、退出码、HAL 失败映射）；真机手验清单（列表与系统设置一致、切换闭环、**插件切换后菜单栏勾选跟随**、外部改默认后 ⌘R 刷新、卸掉 App 触发安装空态）；证据留存方式。
5. **分发与版本**：[0020 Resolution](0020-store-publish-distribution-decision.md) 的路线（脚本为主/Formula 为辅）、三条安装命令文本、Release 与 `install.sh`/`release.sh` 契约、协议演进规则；**prerequisites 写明主仓须公开**，附手工发布清单（tag → `gh release create` → tap 更新）。
6. **风险与遗留**：审核风险、ad-hoc/公证状态、无 CI 的发布纪律。

产出：`.issues/0023-voiceinput-raycast-spec.md`（wayfinder:spec, ready-for-agent），并关本图 [0014](0014-raycast-plugin-map.md)。

## Resolution

（待定）

## Resolution

（closed 2026-10-24）产出 [0023 VoiceInput CLI 契约 + Raycast 插件规格](0023-voiceinput-raycast-spec.md)（`wayfinder:spec` + `ready-for-agent`，16 KB）。

- **逐字可抄的部分**：CLI 命令面 / JSON 形状 / 退出码与错误码 / 版本握手 / 执行预算；插件 manifest、列表项、动作、错误映射、中英文案、偏好设置；三条安装命令文本；`install.sh` 与 `release.sh` 契约。
- **既有 API 可见性改动**：`MenuModel.displayNames(for:)` 需从 internal 改 `public`（CLI 在另一个 module，序号规则不得复制）。
- **两个真机坑的修法写进规格**：查询词继承（丢弃挂载后 400 ms 的 `onSearchTextChange`）、语言判定（`defaults read -g AppleLanguages`，不用 `Intl`）。
- **前置条件单列**：主仓 public、真实 Raycast `author`、首个 Release、≥3 张截图。
- **验收清单**：Swift 门禁 / 契约命令 / `ray lint` 全绿 / 10 条真机手验 / `install.sh` 干净路径跑通 / Store 资产就位。
- **风险表**：审核拒稿、ad-hoc 签名、protocol 演进、无 CI、查询词继承依赖平台行为。

至此地图 [0014](0014-raycast-plugin-map.md) 的 Destination「契约 + 插件规格定稿」达成，关图。
