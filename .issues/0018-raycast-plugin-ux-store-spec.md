---
id: "0018"
title: "插件 UX 与 Store 规格定稿：命令、动作、空态、i18n、元数据"
labels: [wayfinder:grilling]
status: closed
claimed-by: "mainline-session"
blocked-by: ["0015"]
---

## Parent

[0014 Raycast 音频输入切换插件 — Wayfinder 地图](0014-raycast-plugin-map.md)

## Question

把 Raycast 侧规格写到「照抄即可编码」的细度。第二轮 grilling 已定（2026-10-24，**不要再问**）：

- 代码落位：仓库内 `raycast/` 独立 TypeScript 工程。
- 一条命令：`切换输入音源`；List 项 = 设备，`isDefault` 标「当前默认」。
- `Enter` = 切换 → `closeMainWindow()` + `showHUD("已切换到 X")`；`⌘R` 重读；`⌘C` 复制名称；`⌘⇧O` 打开声音设置；`⌘⇧V` 打开 VoiceInput。
- 偏好设置 `cliPath`（留空自动探测 `/Applications`、`~/Applications`）。
- 缺 CLI：空态 +「复制安装命令」动作（安装命令文本随 [0020](0020-store-publish-distribution-decision.md) 的分发路线定稿）。
- 中英文都要：界面文案与设置项双语。
- 禁止陈旧：不用 `useCachedPromise` 的缓存语义、不用 `Cache` API；每次命令启动与 `⌘R` 都现调 CLI。
- 退出码 4（设备消失）→ 自动重读 + HUD「设备已断开，列表已刷新」。
- 列表不排序（HAL 原序）。

仍需拍板（依赖 [0015](0015-raycast-extension-platform-store.md) 的平台事实）：

1. **命令面**：单命令是否足够？还是拆「列表/切换」两条命令（Raycast 里两条命令 = 两个入口，搜索命中不同）？
2. **项内容**：主标题=设备名、副标题=「当前默认」/传输类型？是否显示 `id`（调试用，建议不显示）？图标策略（统一 `mic` 还是按 transport 区分——注意 transport 判定成本）。
3. **文案原文**：中英双语全部串（标题、副标题、HUD 成功/失败、四种错误态、空态、偏好设置 label/description/placeholder、复制安装命令的 toast）。
4. **错误映射**：退出码 `2/3/4` + spawn `ENOENT` + 超时 → 各自显示什么（toast / 空态 / 带重试动作的错误视图）。
5. **Store 元数据**：标题、描述（英文为主）、分类（建议 `System`？以 0015 的目录清单为准）、icon 规格与来源（复用 App 的麦克风图标？）、截图张数与内容、README 结构、`preferences` schema。
6. **开发回路**：`npm run dev` 加载步骤、`ray lint` 必过项、目录/文件命名约定（`src/switch-input.tsx` 等）。
7. **i18n 落地方式**：Raycast 的本地化机制（若平台不支持 per-locale，如何在同界面双语表达）。

## 输入（0015 已关，约束已落定）

- 默认探测路径必须指向 **helper**：`<App>.app/Contents/MacOS/voiceinput-cli`（`/Applications`、`~/Applications` 两处），不是 App 主二进制。
- 缓存纪律已定：`useCachedPromise` / `useExec` / `useCachedState` / `Cache` **全部禁用**；用 `usePromise`（无 initialData）或 `useState` + `useEffect`，加载中保持 `List.isLoading`，仅「非加载且 0 设备」才渲染空态（防 EmptyView 闪烁）。
- Store 元数据已有硬清单：MIT、真实 Raycast 账号 author、512×512 PNG、≥3 张 16:10 截图、`CHANGELOG.md`（`{PR_MERGE_DATE}`）、说明伴侣 App 依赖的 README。
- 待你拍板的项可以引用平台事实，但**不要重问**「execFile 能不能用」（能）。
- 契约已冻结（[0017 Resolution](0017-cli-contract.md)）：项主标题用 `displayName`（已含同名序号）、`isDefault` 判断「当前默认」、**不要显示 id/UID**；错误按 `error.code`（`bad_usage`/`hal_error`/`device_not_found`/`switch_failed`）与超时状态映射，不解析 stderr 文本。
- 详见 [0015 Resolution](0015-raycast-extension-platform-store.md) 与 `research/raycast-extension-platform.md`。

## Resolution

（待定）

## Resolution

（closed 2026-10-24。**一条命令**：输入即见设备列表，选中按 `Enter` 就切换——主人原话，不做第二条命令。）

### 命令

| 项 | 值 |
|---|---|
| manifest `name` | `switch-input`（文件 `src/switch-input.tsx`） |
| `title` | `Switch Audio Input` |
| `subtitle` | `VoiceInput` |
| `description` | `List macOS audio input devices and switch the system default in real time.` |
| `mode` | `view` |

### 列表项

- 主标题 `displayName`（契约已含同名序号）；**不显示 id/UID**。
- 默认输入项：`accessories: [{ tag: "Current" | "当前", icon: Icon.CheckCircle }]`；非默认项无 accessory。
- 图标统一 `Icon.Microphone`；副标题留空（`transport` 不在冻结契约内，要显示时按「加字段不 +1」补，本版不加）。
- 列表不排序，保持 helper 输出的 HAL 原序。

### 动作与快捷键

| 动作 | 英文 / 中文 | 快捷键 |
|---|---|---|
| 切换（Primary） | `Switch to This Input` / `切换到此音源` | `↵` |
| 刷新 | `Refresh` / `刷新` | `⌘R` |
| 复制设备名 | `Copy Device Name` / `复制设备名称` | `⌘C` |
| 打开声音设置 | `Open Sound Settings` / `打开声音设置` | `⌘⇧O` |
| 打开 VoiceInput | `Open VoiceInput` / `打开 VoiceInput` | `⌘⇧V` |

切换成功 → `showHUD("Switched to {name}" / "已切换到 {name}")`；若实测 `showHUD` 不自动关窗，则补 `closeMainWindow()`（由 [0021](0021-raycast-skeleton-prototype.md) 原型裁决，两者都可接受）。

### 错误映射

| 情况 | 界面 |
|---|---|
| helper 不存在（`ENOENT`） | 缺 CLI 空态（不是错误页） |
| 退出 `2 bad_usage` | 错误页 `Cannot read audio devices` / `无法读取音频设备` + Retry |
| 退出 `3 hal_error` | 同上 |
| 退出 `4 device_not_found` | 自动重读 + HUD `Device disconnected — list refreshed` / `设备已断开，列表已刷新` |
| 退出 `4 switch_failed` | 重读 + HUD `Could not switch input` / `切换输入失败` |
| 超时（2000ms） | 错误页 `Reading devices timed out` / `读取设备超时` + Retry |
| JSON 解析失败或 `protocol` 不兼容 | 错误页 `VoiceInput is out of date` / `VoiceInput 版本过旧` + 复制升级命令 |

### 缺 CLI 空态

- 标题：`VoiceInput Not Installed` / `未安装 VoiceInput`
- 描述：`Install the VoiceInput companion app to list and switch audio inputs.` / `安装 VoiceInput 伴侣应用后，即可列出并切换音频输入设备。`
- 动作：`Copy Install Command` / `复制安装命令`（命令文本由 [0020](0020-store-publish-distribution-decision.md) 定）、`Open Installation Guide` / `打开安装指南`、`Retry` / `重试`、`Open Extension Preferences` / `打开扩展设置`

### 偏好设置

| 字段 | 值 |
|---|---|
| `name` | `cliPath` |
| `title` | `CLI Path` / `CLI 路径` |
| `description` | `Optional. Leave empty to auto-detect /Applications and ~/Applications.` / `可选。留空则自动探测 /Applications 与 ~/Applications。` |
| `type` | `textfield`，`required: false` |
| `placeholder` | `/Applications/VoiceInput.app/Contents/MacOS/voiceinput-cli` |

### 语言

- manifest 元数据**静态英文**（Raycast 无 per-locale 机制，Store 按英文审）。
- 自有 UI 文案按系统语言：`zh-*` → 中文，否则英文；不加手动切换开关。
- 设备名始终是系统原文（中文系统自然中文）。

### 新鲜度纪律（硬约束）

- 禁用 `useCachedPromise` / `useExec` / `useCachedState` / `Cache`；用 `usePromise`（无 `initialData`）或 `useState` + `useEffect`，挂载即调 helper。
- 加载中保持 `List.isLoading`，**仅「非加载且 0 设备」才渲染空态**（防 `EmptyView` 闪烁）。
- `⌘R` 无条件重新执行一次 helper。

### Store 元数据与资产

- `name`: `switch-input` 所属扩展名 `voice-input-switcher`；`title`: `VoiceInput Audio Switcher`
- `description`: `List and switch macOS audio input devices in real time via the VoiceInput menubar app.`
- `categories`: `["System", "Productivity"]`；`license`: `MIT`；`platforms`: `["macOS"]`
- 图标：复用 App 麦克风素材，512×512 PNG（浅/深色均可读）
- 截图 3 张（16:10 · 2000×1250）：设备列表（含 Current 标记）、缺 CLI 安装空态、切换后的 HUD
- `README.md` 中英双语，开头写明「需先安装 VoiceInput.app」；`CHANGELOG.md` 初版用 `{PR_MERGE_DATE}`
- 扩展名若被占用，备选 `voiceinput-input-switcher`（发布时才可知）

### 工程结构与回路

```
raycast/
  package.json  tsconfig.json  .eslintrc?  README.md  CHANGELOG.md  icon.png  metadata/
  src/switch-input.tsx
  src/lib/cli.ts        // 唯一 execFile 处：listDevices() / setDefault(id)
  src/lib/types.ts      // 契约类型
  src/lib/i18n.ts       // en/zh 文案表
  src/lib/*.test.ts     // Vitest + vi.mock("@raycast/api")
```

- scripts：`dev` = `ray develop`、`lint` = `ray lint`、`build` = `ray build -e dist`、`test` = `vitest run`、`publish` = `npx @raycast/api@latest publish`。
- UI 层不碰 `execFile`；协议解析、路径探测、错误映射全在 `src/lib/cli.ts`，Vitest 脱离 GUI 覆盖。

### 明确不做

第二条命令、设备副标题显示传输类型、手动语言开关、任何跨运行缓存。
