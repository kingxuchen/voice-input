---
id: "0017"
title: "接口契约定稿：CLI 命令面、JSON 协议、退出码与版本握手"
labels: [wayfinder:grilling]
status: closed
claimed-by: "mainline-session"
blocked-by: []
---

## Parent

[0014 Raycast 音频输入切换插件 — Wayfinder 地图](0014-raycast-plugin-map.md)

## Question

把 VoiceInput 的对外 CLI 契约钉死到「插件可照写解析器」的细度。第二轮 grilling 已定骨架（2026-10-24，**不要再问**）：

- 形态：`.app` 内独立可执行 `Contents/MacOS/voiceinput-cli`（新 SwiftPM executable target，复用 `VoiceInputCore`，不启动 `NSApp`）。
- 命令：`list --json`、`set-default <id> --json`、`version --json`。
- 输出：`{"protocol":1,"devices":[{"id":115,"name":"BlackHole 2ch","isDefault":true}],"defaultDeviceID":115}`；`set-default` 返回**切换后回读**的状态。
- 退出码：`0` 成功／`2` 参数错／`3` HAL 读取失败／`4` 设备不存在或切换失败；诊断信息走 stderr 单行。
- 不持久化设备 ID（`AudioDeviceID` 重启漂移）；列表保持 HAL 原序。

仍需拍板：

1. **参数风格**：子命令 `list` / `set-default <id>`，还是 flag 风格 `--list` / `--set-default <id>`？未知子命令/多余参数的行为（退出码 2 + 用法提示？）。
2. **同名设备**：0004 已定菜单对同名追加序号（"麦克风"、"麦克风 2"），永不露 UID。CLI 只给原始 `name`（插件复刻序号规则），还是直接给 `displayName`（单一真相在 Swift 侧）？→ 选一个，写明理由与以后改名成本。
3. **错误 JSON**：非零退出码时 stdout 是否也给结构化 `{"error":{"code":"hal_error|device_not_found|switch_failed|bad_usage","message":"…"}}`，还是只靠退出码 + stderr 文本？
4. **版本握手**：`protocol` 随 `list` 内嵌即可，还是必须有独立 `version --json`？插件遇到「CLI 缺失 / protocol 不匹配（旧 App）」时分别呈现什么（降级为只读？引导升级？）。
5. **健壮性预算**：插件侧 `execFile` 超时值（建议 2000ms）与超时后的用户可见行为；stdout 大小上限；非 UTF-8 名称的处理。
6. **打包与签名**：`bundle-app.sh` 如何把 helper 复制进 bundle、ad-hoc 重签顺序（inside-out 先签 helper 再签 .app？）、`swift build` 产物路径定位（禁止写死）。
7. 已否决项确认：不做 `--watch`/流式输出，不做本地 IPC/socket。

## Resolution

（待定）

## Resolution

（closed 2026-10-24，8 项全部按推荐定稿。以下是可逐字照抄的契约，SPEC 直接引用本节。）

### 术语

- **helper**：`<VoiceInput.app>/Contents/MacOS/voiceinput-cli`，机器调用的可执行文件（独立 SwiftPM executable target，复用 `VoiceInputCore`，不启动 `NSApp`）。
- **App**：`VoiceInput.app` 本体（菜单栏 UI）。插件只认 helper。

### 命令面

```
voiceinput-cli list [--pretty]
voiceinput-cli set-default <id> [--pretty]
voiceinput-cli version [--pretty]
```

- 子命令风格；**JSON 恒输出**（不设 `--json`），默认单行紧凑；`--pretty` 为 2 空格缩进的人肉调试开关。
- `<id>` 必须是十进制无符号整数（`AudioDeviceID`）；非数字 → `bad_usage`。
- 未知子命令／多余参数／无参数 → `bad_usage`（stderr 打用法）。

### 成功输出

`list`（也是 `set-default` 成功后的形状——**返回完整新状态**）：

```json
{"protocol":1,"devices":[{"id":115,"name":"BlackHole 2ch","displayName":"BlackHole 2ch","isDefault":true}]}
```

- `name` = HAL 系统原文；`displayName` = 同名加序号的用户可见名（"麦克风" / "麦克风 2"），**序号规则只在 Swift 侧实现**（复用 `MenuModel`），插件只渲染 `displayName`，永不显示 id/UID。
- **无 `defaultDeviceID` 顶层字段**：同一事实只在 `devices[].isDefault` 表达。
- 顺序 = HAL 原序（沿用 0004），helper 不排序。
- `set-default` 成功 = 写入后**回读**再输出（不是回显入参）。

`version`：

```json
{"protocol":1,"appVersion":"1.0.0"}
```

### 错误输出

stdout 也给结构化错误，stderr 另打一行人话：

```json
{"protocol":1,"error":{"code":"hal_error","message":"…"}}
```

| 退出码 | `code` | 触发 |
|---|---|---|
| `0` | — | 成功 |
| `2` | `bad_usage` | 子命令/参数/`<id>` 形状错 |
| `3` | `hal_error` | 设备枚举失败，**或当前默认输入读取失败**（读不到默认就无法诚实地打勾，宁可报错也不说谎） |
| `4` | `device_not_found` | `<id>` 不在当前输入设备集合里 |
| `4` | `switch_failed` | `AudioObjectSetPropertyData` 写入失败 |

### 版本握手

- `protocol` 起始为 `1`，只在**破坏性**变更时 +1；加字段不 +1。
- `list`/`set-default` 响应顶层带 `protocol`，`version` 供显式检查。
- 插件策略：helper 缺失 → 安装空态；`protocol` < 插件最低要求 → 「VoiceInput 太旧」+ 复制升级命令；`protocol` > 插件支持 → 「插件太旧」+ 打开扩展更新页。

### 插件侧执行预算

- `execFile`：`timeout` 2000 ms（先 SIGTERM，3000 ms 未退则 SIGKILL）、`maxBuffer` 1 MB。
- 超时 → 错误视图「读取设备超时」+ 重试动作；设备名非法 UTF-8 → 替换字符，不丢设备。
- 不持久化设备 id（重启漂移）；退出码 4 → 自动重读 + HUD「设备已断开，列表已刷新」。

### 打包与签名

- `bundle-app.sh` 用 `swift build -c release --show-bin-path` 动态取 helper（禁止写死 `.build`），复制进 `Contents/MacOS/voiceinput-cli`。
- **先签 helper，再签 `.app` 根**（ad-hoc `codesign --force --sign -`），收尾 `codesign --verify --strict`；签名禁用 `--deep`（macOS 13 起 deprecated for signing）。
- 单测在 SwiftPM 内跑（helper 逻辑放在可测试的 Core/CLI 层），不在 `.app` 里跑。

### 明确不做

`--watch`/流式输出、本地 IPC/socket、任何落盘缓存文件。一次调用 = 一个进程 = 一次 HAL 现读，这是「无陈旧数据」的唯一保证。
