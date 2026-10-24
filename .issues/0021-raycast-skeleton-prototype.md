---
id: "0021"
title: "插件骨架原型：List + 动作 + 真实 CLI 调用手感验证"
labels: [wayfinder:prototype]
status: closed
claimed-by: "mainline-session"
blocked-by: ["0015", "0017"]
---

## Parent

[0014 Raycast 音频输入切换插件 — Wayfinder 地图](0014-raycast-plugin-map.md)

## Question

用最便宜的方式把「Raycast 里到底长什么样、点起来什么手感、`execFile` 在扩展进程里真的能用吗」变成可以看、可以点的东西，喂给 [0018](0018-raycast-plugin-ux-store-spec.md) 的定稿。

范围（原型，不是交付）：

- `raycast/` 里可 `npm run dev` 加载的最小扩展：一条命令 + `List`，项来自 **JSON fixture**（形状照 [0017 Resolution](0017-cli-contract.md) 的冻结 schema：`protocol`/`devices[].displayName`/`isDefault`，错误用 `error.code`）或**真实 `voiceinput-cli`**（若该 helper 已存在——本图不实现它，没有就先用 fixture）。
- 动作：`Enter` 触发一次真实/桩调用 → `showHUD()`（若实测不自动关窗再补 `closeMainWindow()`）；`⌘R` 重读。
- 缺 CLI 空态与「复制安装命令」的观感。
- 自有文案 en/zh 在真实界面里的排版（manifest 已定静态英文，此处只验 UI 文案切换）。

必须回答：Raycast 内 `execFile` 是否可用（权限/提示）；**`showHUD` 是否自动关闭主窗口**（不自动则需补 `closeMainWindow`，见 [0018 Resolution](0018-raycast-plugin-ux-store-spec.md)）；列表项信息密度是否够；系统语言判定（`zh-*` → 中文）在真实 Raycast 进程里是否可靠。

产出：原型代码（留在 `raycast/` 作为后续实现的种子或明确标注为丢弃）+ 真机截图 + 结论段落。资产链接回本票，正文不粘贴大段代码。

## Resolution

（待定）

## Resolution

（closed 2026-10-24。原型落地在 `raycast/`，**已真机跑通核心闭环**，并顺带证实/推翻三条原假设。）

### 产物

```
raycast/
  package.json  tsconfig.json  eslint.config.js  vitest.config.mts
  README.md  CHANGELOG.md  assets/icon.png  metadata/01-device-list.png
  src/switch-input.tsx
  src/lib/{cli,types,i18n,constants,locale}.ts
  src/lib/{cli,i18n}.test.ts
  src/test/raycast-api-stub.ts
```

门禁：`npm run build` 通过；`vitest run` **8 tests passed**；`ray lint` 只剩 `author` 一项（见下）。

### 必须回答的四问（真机实证）

1. **`execFile` 在扩展进程可用** —— 是。无沙箱、无权限提示，直接执行 `~/Applications/VoiceInput.app/Contents/MacOS/voiceinput-cli` 并读到 JSON。
2. **`showHUD` 是否自动关主窗口** —— **是，不需要补 `closeMainWindow()`**。实测：回车切换后主窗口在 **261–329 ms** 内消失（同一时刻 HAL 默认输入已变），窗口消失与切换完成几乎同时。
3. **列表信息密度** —— 够。8 台设备单屏放下，主标题 `displayName`、右侧 `当前` 标签 + 勾选图标，底部动作条 `切换到此音源 ↵ / Actions ⌘K` 无溢出（截图见 `raycast/metadata/01-device-list.png`）。
4. **系统语言判定** —— **`Intl` 不可靠，已推翻原方案**。Raycast 的 Node 运行时在本机（系统中文）把 locale 报成 `en-CN-u-ca-gregory-hc-h23`，基础语言是 `en`。改用 `defaults read -g AppleLanguages` 取首项（本机 `zh-Hans-CN`），中文文案才正确生效。

### 真机另抓到一个必踩的坑（已修）

**Raycast 会把根搜索的查询词带进命令的搜索框。** 用 `switch audio` 搜到命令再回车，该查询词经 `onSearchTextChange` 推给命令，把设备列表过滤成 `No Results`——即用户最自然的用法直接不可用。三种修法实测：

| 做法 | 结果 |
|---|---|
| 受控 `searchText=""` | ❌ 盖不住，注入发生在挂载后 |
| 受控 + 初值 `undefined` 再清 | ❌ React 警告「uncontrolled → controlled」，且仍过滤 |
| **丢弃挂载后 400 ms 内的 `onSearchTextChange` 推送** | ✅ 列表正常，之后的用户输入正常生效 |

最终实现：`mountedAt` 时间戳 + `handleSearchTextChange` 里按时间窗丢弃首个继承值。

### 验收动作实测

| 项 | 结果 |
|---|---|
| 设备列表（8 台，HAL 原序） | ✅ 与 `voiceinput-cli list` 逐条一致 |
| `当前` 标记位置 | ✅ 跟随 `isDefault` |
| `Enter` 切换 | ✅ `177 → 209`，261–329 ms |
| 切换后窗口关闭（`showHUD`） | ✅ 自动 |
| `⌘R` 重读 | ✅ 外部改默认（→172 TFFAudio）后按 `⌘R`，`当前` 立即移到 TFFAudio |
| 缺 CLI 空态 | ✅ `未安装 VoiceInput` + 描述 + `复制安装命令` |
| 中文文案 | ✅ `切换到此音源…` / `当前` |
| `device_not_found` 错误路径 | ✅ CLI 桩返回 `exit=4` + `{"error":{"code":"device_not_found",…}}` |

### 遗留（交接给 SPEC / 实现）

- `package.json` 的 `author` 必须是主人**真实的 Raycast 账号名**；`kingxuchen` 在 raycast.com 不存在（`ray lint` 唯一未过项）。发布前替换。
- 截图目前只有 1 张（设备列表），Store 要求 ≥3 张：还需「缺 CLI 空态」与「切换后 HUD」各一张。
- 原型用的 helper 是 `/tmp/vi-probe/voiceinput-cli`（按 0017 契约手写的 HAL 桩，**不是**仓库里的产品代码）；验证后已从 `~/Applications` 移除，仓库无残留。
- 真机驱动脚本（AX + CGEvent）同样只在 `/tmp/vi-probe/`，未入库。
