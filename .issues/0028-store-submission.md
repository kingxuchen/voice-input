---
id: "0028"
title: "Store 提交包：截图、文档与 lint 全绿"
labels: [ready-for-agent]
status: open
claimed-by: ""
blocked-by: ["0025", "0027"]
---

## Parent

[0023 VoiceInput CLI 契约 + Raycast 插件规格](0023-voiceinput-raycast-spec.md)（§F Store 元数据）

## What to build

让扩展**够格被审**：仓库里那一条 `ray lint` 的未过项（作者账号）消掉，Store 要求的资产补齐，然后提交一个审核员看得懂「这插件需要先装伴侣 App」的 PR。

- 元数据：真实 Raycast 账号作为作者、名称/描述/分类/许可证按规格。
- 资产：≥3 张 16:10 截图（设备列表含「当前」、缺 CLI 安装空态、切换后的 HUD），512×512 图标。
- 文档：双语 README（开头写清前置条件与安装命令）、CHANGELOG 初版。
- 提交：`ray lint` 全绿 → 构建 → 提交 PR，PR 说明里主动交代依赖外部 App 的设计原因。

## Acceptance criteria

- [ ] `ray lint` 全绿（作者账号为真实 Raycast 账号，无 404）
- [ ] 3 张以上截图，尺寸与比例符合要求，画面无隐私信息
- [ ] README 双语且明确写出「需先安装 VoiceInput」及安装命令
- [ ] CHANGELOG 含初版条目与合并日期占位符
- [ ] `npm run build` 通过，`publish` 流程可执行并成功提出 PR
- [ ] PR 描述说明：为何依赖外部伴侣 App、空态如何引导安装、数据为何不用缓存

## Blocked by

- [首发分发包：安装脚本 + Release 产物](0025-install-and-release.md)
- [插件异常面与双语收口：四种错误态 + 中英文案](0027-plugin-error-and-i18n.md)
