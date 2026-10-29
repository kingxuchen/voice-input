---
id: "0023"
title: "VoiceInput CLI 契约 + Raycast 插件规格（SPEC）"
labels: [wayfinder:spec, ready-for-agent]
status: open
claimed-by: ""
blocked-by: []
---

# VoiceInput CLI 契约 + Raycast 插件规格

汇总自：[0017 接口契约](0017-cli-contract.md) · [0018 插件 UX 与 Store 规格](0018-raycast-plugin-ux-store-spec.md) · [0019 菜单新鲜度复验](0019-menu-freshness-baseline.md) · [0020 分发决策](0020-store-publish-distribution-decision.md) · [0021 插件骨架原型](0021-raycast-skeleton-prototype.md) · 研究：[0015 平台](0015-raycast-extension-platform-store.md)｜[0016 分发](0016-companion-app-distribution.md)

## Problem Statement

切换 macOS 输入音源要么点菜单栏、要么进「系统设置 › 声音 › 输入」，在听写 / 会议 / 录音这些高频换麦场景里路径太深。已有的 VoiceInput 菜单栏 App 解决了「不用开设置」，但仍要离开当前工作流去点菜单栏。

主人要的是：**在 Raycast 里敲一条命令 → 看到全部输入设备 → 回车就切**。并且两条硬约束：

1. 每次获取都必须是 macOS 的**当前真实状态**，绝不允许显示上一次的结果（缓存即说谎）；
2. 旧应用自己展开菜单时，同样必须是实时音源与当前选中。

## Solution

- **App 侧**：`VoiceInput.app` 内新增一个机器调用的 helper —— `Contents/MacOS/voiceinput-cli`，独立可执行、复用 `VoiceInputCore` 的 HAL 实现，对外一份冻结的 JSON 契约。一次调用 = 一个进程 = 一次 HAL 现读，天然无陈旧数据。
- **插件侧**：仓库内 `raycast/` 独立 TypeScript 工程，一条 `view` 模式命令，`List` 展示设备、`Enter` 切换、`showHUD` 反馈。
- **分发**：主仓转 public，`curl | bash` 安装脚本为主、Homebrew Formula 为辅；App 先发、扩展后发。

## 前置条件（不满足则无法发布，但可本地自用）

| # | 条件 | 现状 |
|---|---|---|
| 1 | 主仓 `kingxuchen/voice-input` 转 **public** | 当前 PRIVATE；主人已认领此动作 |
| 2 | `raycast/package.json` 的 `author` 换成**真实 Raycast 账号名** | 当前 `kingxuchen` 在 raycast.com 404，`ray lint` 唯一未过项 |
| 3 | 首个 Release `v1.0.0`（含 helper 的 `.app` zip + `.sha256`） | 无 tag、无 release |
| 4 | Store 截图 ≥3 张（16:10 · 2000×1250） | 只有 1 张（设备列表） |

## User Stories

1. 作为用户，我在 Raycast 敲「switch audio」就能看到全部输入设备，不用离开键盘。
2. 作为用户，我按下回车就用上那支麦克风，并通过 HUD 知道切换成功。
3. 作为用户，我改完系统默认输入再打开命令，看到的就是新状态（不会闪一下旧列表）。
4. 作为用户，我在插件里切换后，菜单栏 App 的勾选立刻跟着变。
5. 作为用户，我没装 VoiceInput 时看到明确的安装引导，而不是崩溃或空白。
6. 作为用户，设备拔掉后我再点那台设备，得到「已断开、列表已刷新」而不是静默失败。
7. 作为用户，我的系统是中文，命令里的自有文案就显示中文；英文系统显示英文。
8. 作为用户，我能用 `⌘R` 手动重读、`⌘C` 复制设备名、`⌘⇧O` 打开声音设置、`⌘⇧V` 打开 VoiceInput。

## Implementation Decisions

### A. CLI 契约（**已冻结**，逐字照做）

**可执行**：`<VoiceInput.app>/Contents/MacOS/voiceinput-cli`（独立 SwiftPM executable target，复用 `VoiceInputCore`，**不启动 `NSApp`**）。

**命令面**

```
voiceinput-cli list [--pretty]
voiceinput-cli set-default <id> [--pretty]
voiceinput-cli version [--pretty]
```

- 子命令风格；**JSON 恒输出**，默认单行紧凑，`--pretty` 为 2 空格缩进（仅人肉调试）。
- `<id>` 必须是十进制无符号整数（`AudioDeviceID`）；未知子命令 / 多余参数 / 无参数 → `bad_usage`。

**成功输出**（`set-default` 成功后返回**回读**的完整新状态）

```json
{"protocol":1,"devices":[{"id":115,"name":"BlackHole 2ch","displayName":"BlackHole 2ch","isDefault":true}]}
```

```json
{"protocol":1,"appVersion":"1.0.0"}
```

- `name` = HAL 系统原文；`displayName` = 同名加序号的用户可见名（`麦克风` / `麦克风 2`），**序号规则只在 Swift 侧实现**。
- **无顶层 `defaultDeviceID`**：同一事实只在 `devices[].isDefault` 表达。
- 顺序 = HAL 原序，helper 不排序。

**错误输出**：stdout 结构化 + stderr 一行人话

```json
{"protocol":1,"error":{"code":"hal_error","message":"…"}}
```

| 退出码 | `code` | 触发 |
|---|---|---|
| `0` | — | 成功 |
| `2` | `bad_usage` | 子命令/参数/`<id>` 形状错 |
| `3` | `hal_error` | HAL 调用**真返回非 `noErr`**：设备枚举、默认输入读取、或 `set-default` 的回读 |
| `4` | `device_not_found` | `<id>` 不在当前输入设备集合里 |
| `4` | `switch_failed` | `AudioObjectSetPropertyData` 写入失败 |

**版本握手**：`protocol` 起始 `1`，仅**破坏性**变更 +1（加字段不 +1）。`list`/`set-default` 响应顶层带 `protocol`，`version` 供显式检查。

**插件侧执行预算**：`execFile` timeout **2000 ms**（先 SIGTERM，再 1000 ms 后 SIGKILL）、`maxBuffer` **1 MB**；超时 → 错误视图 + 重试；设备名非法 UTF-8 → 替换字符，不丢设备。
（测算依据：helper 冷启动首次 HAL 枚举实测 190–270 ms，热路径 2 ms；2000 ms 有充足余量。）

**明确不做**：`--watch` / 流式、本地 IPC/socket、任何落盘缓存文件。

### B. App 侧改动清单

1. `Package.swift` 新增 `executableTarget(name: "VoiceInputCLI", dependencies: ["VoiceInputCore"])`，产物名 `voiceinput-cli`。
2. **实现落点（2026-10-24 实现后修订）**：解析、执行、编码放在 `VoiceInputCore`（`CLI.swift`），可执行目标只调一个公开入口 `CLIEntry.run(arguments:appVersion:)` 并退出——放在库里才能被单测直接驱动，`CLIEntry` 是唯一 public 符号。不链接 SwiftUI/AppKit 主循环。
3. **`MenuModel.displayNames(for:)` 保持 internal**（原计划改 public 是错判：CLIRunner 本就在同一 module）。序号规则只有一份，不复制到 CLI。
   读失败只有一种：HAL 返回非 `noErr` → `hal_error`。**「HAL 答没有」不算读失败**（2026-10-29 修订）：枚举为空 → `devices: []` 的成功响应；没有默认输入、或默认 id 不在枚举里 → 列表照给、没人带 `isDefault: true`。原先这三者被压成 `hal_error`，导致插件把「真没有设备」渲染成「无法读取」。
4. `scripts/bundle-app.sh`：
   - 用 `swift build -c release --show-bin-path` 动态取 `voiceinput-cli`（**禁止写死 `.build` 路径**）；
   - 复制进 `Contents/MacOS/voiceinput-cli`；
   - **先签 helper，再签 `.app` 根**（ad-hoc `codesign --force --sign -`），收尾 `codesign --verify --strict`；
   - 签名禁用 `--deep`（macOS 13 起 deprecated for signing）。
5. 新增 `scripts/install.sh`（契约见 D）。
6. 新增 `scripts/release.sh`（契约见 D）。
7. 单测：helper 的 JSON 形状、退出码、错误映射（`hal_error` 分支可用注入的假 provider 或参数校验路径覆盖；真实 HAL 只读测试沿用现有先例）。

> 版本单一来源：`scripts/bundle-app.sh` 的 `VERSION`；helper 的 `version.appVersion` 与 bundle 版本同源。

### C. 插件规格（**已真机验证**，`raycast/` 已有原型）

```
raycast/
  package.json  tsconfig.json  eslint.config.js  vitest.config.mts
  README.md  CHANGELOG.md  assets/icon.png  metadata/*
  src/switch-input.tsx            // 单条命令：取数 + 渲染 + 副作用派发，不含判定
  src/lib/cli.ts                  // 唯一 execFile 处：listDevices() / setDefault()
  src/lib/types.ts                // 契约类型（只放 CLI 协议模型）
  src/lib/presentation.ts         // 视图模型：CLI 结果 → 界面状态 → 该画哪个空态
  src/lib/searchText.ts           // 查询词继承的丢弃窗口（400 ms）
  src/lib/filter.ts               // 自建搜索过滤
  src/lib/feedback.ts             // 切换结果 → 反馈决定
  src/lib/i18n.ts                 // en/zh 文案表
  src/lib/constants.ts            // 安装命令、深链、App 路径
  src/lib/locale.ts               // 系统语言探测
  src/lib/*.test.ts
  src/test/raycast-api-stub.ts    // vitest 的 @raycast/api 桩
```

**命令**（manifest）：`name: switch-input`｜`title: Switch Audio Input`｜`subtitle: VoiceInput`｜`mode: view`｜`categories: ["System","Productivity"]`｜`license: MIT`｜`platforms: ["macOS"]`。

**列表项**：主标题 `displayName`；默认项 `accessories: [{ tag: 当前/Current, icon: Icon.CheckCircle }]`；统一 `Icon.Microphone`；不显示 id/UID；不排序（HAL 原序）。

**搜索（2026-10-24 追加）**：过滤由插件自己做，不用 Raycast 内建过滤。原因：一旦传 `onSearchTextChange`，`List.filtering` 默认就是 `false`（输入不进过滤，界面纹丝不动）；而打开内建过滤又会被根搜索带进来的查询词污染。规则：大小写不敏感的子串匹配 `name` 或 `displayName`；空查询返回全量并保持 HAL 原序；无匹配时给独立空态「没有匹配的设备 / No matching devices」+「清空搜索」动作，与「真的没有设备」区分开。

**动作**：`↵` 切换 · `⌘R` 刷新 · `⌘C` 复制设备名 · `⌘⇧O` 打开声音设置（`x-apple.systempreferences:com.apple.Sound-Settings.extension`） · `⌘⇧V` 打开 VoiceInput。

**切换反馈**：成功 → `showHUD(已切换到 {name})`。**实测 `showHUD` 会自动关闭主窗口**（261–329 ms），不要再调 `closeMainWindow()`。

**错误映射**

| 情况 | 界面 |
|---|---|
| `ENOENT` / `EACCES` | 缺 CLI 空态（不是错误页） |
| 退出 `2 bad_usage` | 错误页「无法读取音频设备」+ 重试 |
| 退出 `3 hal_error` | 同上 |
| 退出 `0` 且 `devices: []` | 空态「未发现可用输入设备 / No input devices found」+ 重试动作（**不是**错误页） |
| 退出 `4 device_not_found` | 自动重读 + HUD「设备已断开，列表已刷新」 |
| 退出 `4 switch_failed` | 重读 + HUD「切换输入失败」 |
| 超时 | 错误页「读取设备超时」+ 重试 |
| JSON 非法 / `protocol` 不匹配 | 错误页「VoiceInput 版本过旧」+ 复制升级命令 |

**缺 CLI 空态**：标题 `未安装 VoiceInput` / `VoiceInput Not Installed`；描述 `安装 VoiceInput 伴侣应用后，即可列出并切换音频输入设备。`；动作 = 复制安装命令（主）/ 复制 Homebrew 命令 / 打开安装指南 / 重试 / 打开扩展设置。

**新鲜度纪律（硬约束）**
- 禁用 `useCachedPromise` / `useExec` / `useCachedState` / `Cache`；用 `usePromise`（无 `initialData`）或 `useState` + `useEffect`，挂载即调 helper。
- 加载中保持 `List.isLoading`；**空态由 `lib/presentation.ts` 的 `emptyStateFor` 一处判定**（`loading` 与「有条目可显示」都返回 `null`，所以不会闪 `EmptyView`），组件里只写一行 `{empty && <List.EmptyView {...empty} />}`。该函数对 `state.kind` 做穷尽 `switch`（没有 `default`），新增状态时漏分支直接编译失败。
- `⌘R` 无条件重新执行 helper。

**两个真机坑（必须保留现有修法）**

1. **查询词继承**：Raycast 会把根搜索的查询注入命令搜索框，把设备列表过滤成 `No Results`（用户最自然的用法直接不可用）。受控 `searchText=""` 与 `undefined` 初值都盖不住。**唯一有效做法**：记录 `mountedAt`，丢弃挂载后 400 ms 内的 `onSearchTextChange` 推送，之后的用户输入正常生效。判据抽在 `lib/searchText.ts`（`ROOT_SEARCH_GRACE_MS` + `shouldDropSearchText`），边界由 `searchText.test.ts` 锁住。
2. **语言判定**：`Intl.DateTimeFormat().resolvedOptions().locale` 在本机中文系统报 `en-CN-…`（基础语言 `en`），不可用。**必须**读 `defaults read -g AppleLanguages` 首项（本机 `zh-Hans-CN`）；`zh*` → 中文，否则英文。

**manifest 元数据静态英文**（Raycast 无 per-locale，Store 按英文审）；双语只落在自有 UI 文案上。

**偏好设置**：`cliPath`（textfield，`required: false`，placeholder `/Applications/VoiceInput.app/Contents/MacOS/voiceinput-cli`），留空自动探测 `/Applications` 与 `~/Applications`。

### D. 分发与发布

**路线**：阶段一 $0 —— 脚本为主、Formula 为辅；阶段二（想零终端体验或审核施压时）Developer ID + 公证。ad-hoc 网络直发与 Cask 均被 Gatekeeper 封死，不作为路径。

**安装命令（空态里复制）**

```bash
curl -fsSL https://raw.githubusercontent.com/kingxuchen/voice-input/main/scripts/install.sh | bash
brew install kingxuchen/tap/voiceinput
```

脚本地址钉 `main`（文本不随版本变），脚本内部再解析最新 release。

**`scripts/install.sh` 契约**（`set -euo pipefail`）

- 环境变量：`VERSION=v1.0.0` 覆盖版本；`BASE_URL` 覆盖下载来源（镜像 / 离线自检用，默认 GitHub Release 地址）。
- 先在暂存路径完成「校验和 → 解压 → helper 预检」，**通过后才替换**已安装 App（原子替换，避免"旧版没了、新版是坏的"）。
- 已有同名 App 时先核对 bundle id，不是本应用则中止（沿用 `bundle-app.sh` 的既有约定）。
1. 解析 latest release（GitHub API；`VERSION=v1.0.0` 可覆盖以规避限流）；
2. 下载 `VoiceInput-<version>.zip` 与 `.sha256` 到临时目录，`shasum -a 256 -c` 校验；
3. `ditto -x -k` 解压 → 替换 `~/Applications/VoiceInput.app`（先删旧）；
4. `xattr -cr ~/Applications/VoiceInput.app`；
5. `open` 一次并打印结果摘要；
6. 任一步失败 → 非零退出 + 明确原因。

**`scripts/release.sh` 契约**：`bundle-app.sh` → `ditto -c -k --keepParent` 打 zip → 生成 `.sha256` → 打印可复制的 `gh release create v<version> …` 命令（**不自动** tag/push/上传）。

**发布顺序**：App 先行（含 helper，`VERSION` 递增）→ 再提 Store 扩展；扩展声明最低 `protocol`；App 升级 = 重跑同一条安装命令。

**Store 提交**：`ray lint` → `ray build` → `npx @raycast/api@latest publish`（自动向公共 `raycast/extensions` 提 PR），macOS runner CI + 人工审核，周期约 2 个工作日到 1–2 周。

### E. 实现顺序建议（供 to-tickets 切片）

1. App 侧 helper + 契约测试 + `bundle-app.sh` 打包签名 → 真机跑 `list` / `set-default` / `version` 三命令。
2. `scripts/install.sh` + `release.sh` + 首个 Release（先把主仓转 public）。
3. 插件把现有原型的 `cliPath` 接到真 helper，删掉 mock 依赖 → 真机验收列表/切换/刷新/错误态。
4. Store 资产补齐（3 张截图、README 双语、CHANGELOG）→ `ray lint` 全绿 → 提 PR。

### F. Store 元数据

- `name`: `voice-input-switcher`；`title`: `VoiceInput Audio Switcher`
- `description`: `List and switch macOS audio input devices in real time via the VoiceInput menubar app.`
- 图标 512×512 PNG（复用 App 麦克风素材，浅/深色均可读）
- 截图 ≥3 张 16:10 · 2000×1250：设备列表（含「当前」）、缺 CLI 安装空态、切换后的 HUD
- `README.md` 中英双语，开头写明「需先安装 VoiceInput.app」
- `CHANGELOG.md` 初版用 `{PR_MERGE_DATE}`

## Testing Decisions

**Swift（App 侧）**
- 测经接缝可见的行为：JSON 形状（含 `displayName` 序号）、退出码 `0/2/3/4`、错误 `code`、`--pretty` 不改变语义、`set-default` 返回回读状态。
- 真实 HAL 只读测试沿用既有先例（枚举/读默认，不写默认）；写入行为走假 provider。
- 打包后**必须**验证签名链：`codesign --verify --strict`，且 helper 先于 App 根签名。

**TypeScript（插件侧）**
- `vitest` + `vi.mock`/alias 桩 `@raycast/api`：解析器（形状/`protocol`/错误码映射）、i18n（`zh*` vs 其他）、`resolveCliPath` 探测顺序。
- 界面该显示什么，全部在 `lib/presentation.ts` 用纯函数覆盖：六种状态各自的图标/标题/动作顺序，重点是三组曾经分不开的情况——「HAL 答没有设备」vs「读不到设备」vs「搜不到」；两种「版本过旧」方向（升级 App / 更新扩展）文案与动作都不同。`lib/searchText.ts` 覆盖丢弃窗口的边界（0 ms、399 ms 丢，400 ms 收）与时钟回拨。
- 不测 React 渲染细节；剩余界面行为由真机手验覆盖。

**真机手验清单（缺一不判通过）**
- [ ] 列表与 `voiceinput-cli list` 逐条一致，顺序一致，8 台设备单屏可读
- [ ] `当前` 标签跟随 `isDefault`
- [ ] `Enter` 切换后系统默认真的变了（第三方探针读 HAL 佐证），HUD 出现且主窗口自动关闭
- [ ] 切换后菜单栏 App 勾选跟随（HAL 监听，无需操作）
- [ ] 外部改默认 → `⌘R` → 列表 `当前` 立即移动
- [ ] 从根搜索带查询进入命令（如 `switch audio`）→ 列表**不是** `No Results`
- [ ] 中文系统显示中文文案、英文系统显示英文
- [ ] 移走 helper → 显示安装空态 + 复制安装命令可用
- [ ] `set-default` 传入已消失的设备 → HUD「设备已断开，列表已刷新」
- [ ] 连续开关命令 5 次，无旧数据闪现
- [ ] `⌘⇧O` 在当前 macOS 能直接打开「声音 › 输入」面板（深链跨版本可靠性，实现期确认）

## 验收清单

- [ ] `swift build` 零警告零错误、`swift test` 全绿
- [ ] `swift build -c release` 产出的 `.app` 内含 `Contents/MacOS/voiceinput-cli`，签名校验通过
- [ ] `voiceinput-cli list|set-default|version` 在真机上返回契约形状，退出码正确
- [ ] `raycast/`：`npm run build` 通过、`npx vitest run` 全绿、`ray lint` 全绿（含 `author` 换成真实账号）
- [ ] 上方真机手验清单逐条勾选，证据（截图/AX 记录）留档
- [ ] `scripts/install.sh` 在干净路径（先删 `~/Applications/VoiceInput.app`）跑通并留输出
- [ ] 主仓已 public、Release `v1.0.0` 已发布、README 安装段可用
- [ ] Store 三张截图与 README/CHANGELOG 就位

## 已知风险

| 风险 | 影响 | 缓解 |
|---|---|---|
| Store 以「依赖用户自装外部 App」拒稿 | 无法上架 | 空态与 README 明确前置条件（Tailscale / AeroSpace 同构先例）；拒稿则退回本地自用，不回滚 App 分发 |
| ad-hoc 签名 + 脚本清隔离 | 用户信任成本；未来 macOS 收紧本地执行 | 阶段二切 Developer ID 公证，扩展只换命令文本 |
| `protocol` 演进 | 旧 App + 新插件 | 三态处理已定（缺 CLI / App 太旧 / 插件太旧） |
| 无 CI | 发布靠手工清单 | `release.sh` 打印可复制命令；发布检查清单进 README |
| 查询词继承是 Raycast 平台行为 | 若未来平台改行为，当前修法可能失效 | 手验清单里保留该条；修法集中在 `lib/searchText.ts` + `handleSearchTextChange` 两处（判据与接线分开），并有单测锁边界 |
