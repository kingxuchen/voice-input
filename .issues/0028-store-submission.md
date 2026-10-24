---
id: "0028"
title: "Store 提交包：截图、文档与 lint 全绿"
labels: [ready-for-agent]
status: open
claimed-by: "impl-0028"
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

## Progress（2026-10-24，资产部分；安装命令已可用）

- 已有合规截图 1 张：`raycast/metadata/01-device-list.png`（2000×1250，设备列表含「当前」）。
- 图标 512×512：`raycast/assets/icon.png`（复用 App 麦克风素材）。
- `README.md` 双语 + 前置条件与两条安装命令；`CHANGELOG.md` 初版含 `{PR_MERGE_DATE}`。
- `ray lint` 除 `author` 外全绿（ESLint / Prettier / manifest 其余字段 / 图标 / metadata 校验均通过）。

**未完成（两处需要你的账号或人工操作）**：
1. `package.json` 的 `author` 必须填**你的真实 Raycast 账号名**——`kingxuchen` 在 raycast.com 返回 404，这是 `ray lint` 唯一未过项。我不知道你的 Raycast 用户名，不能猜。
2. 还差 2 张截图（缺 CLI 安装空态、切换后的 HUD）。自动化抓 Raycast 主窗口不稳定（窗口常在其他 Space，抓出来是空白），建议发布前在界面里手动截：打开命令 → `⇧⌘4` 空格选窗口。
3. 提交 `npx ray publish`（会向公共 `raycast/extensions` 提 PR，属对外可见动作，需你确认后执行）。

### 更新（2026-10-24，0025 已关）

- 安装脚本已在公网可用：`curl -fsSL https://raw.githubusercontent.com/kingxuchen/voice-input/main/scripts/install.sh | bash`（实测通过），README 里的命令不再是 404。
- 剩余两项仍需你操作，见上。
- **截图抓取建议**（自动化抓 Raycast 主窗口不稳定：窗口常在其他 Space，抓出来是空白）：
  1. 打开命令并停在目标画面；
  2. `⇧⌘4` 后按空格，鼠标点窗口即可；
  3. 用 `sips -z 1250 2000 <file>.png` 调成 2000×1250。
  `ray lint` 会校验尺寸，不达标会直接报错。
