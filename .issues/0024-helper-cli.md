---
id: "0024"
title: "helper CLI 落地：voiceinput-cli 三命令与打包签名"
labels: [ready-for-agent]
status: closed
claimed-by: "impl-0024"
blocked-by: []
---

## Parent

[0023 VoiceInput CLI 契约 + Raycast 插件规格](0023-voiceinput-raycast-spec.md)（§A 契约、§B App 侧改动清单）

## What to build

让装好的 VoiceInput 里存在一个**机器可调用**的 helper，外部（Raycast、终端）执行它就能拿到当前真实的输入设备列表、切换系统默认输入、读协议版本——每次调用都是一次进程、一次 HAL 现读，因此天然没有陈旧数据。

对外表现（`voiceinput-cli`）：

- `list` → `{"protocol":1,"devices":[{id,name,displayName,isDefault}]}`，HAL 原序，同名设备带序号，`isDefault` 只有一处表达；
- `set-default <id>` → 写入后**回读**同一形状，不是回显入参；
- `version` → `{"protocol":1,"appVersion":"…"}`；
- 失败时 stdout 给结构化错误码（`bad_usage` / `hal_error` / `device_not_found` / `switch_failed`）+ 退出码 `2/3/4`，stderr 一行人话；
- `--pretty` 只影响排版，不改变语义。

helper 随 `.app` 一起分发，签名链正确（先签 helper、再签 App 根），不启动 `NSApp`。

## Acceptance criteria

- [ ] 打包产物的 `.app` 内可直接执行 helper；`swift build -c release` 后 helper 与 App 版本同源
- [ ] 三个子命令在真机返回规格 §A 的 JSON 形状与退出码（含四类失败：参数错、HAL 读失败、设备不存在、切换失败）
- [ ] `list` 的 `displayName` 与菜单栏 App 的同名序号规则一致（规则只有一份实现，没有复制）
- [ ] 当前默认输入读取失败时**报错而不是**返回无勾选的列表
- [ ] `--pretty` 输出可读且与紧凑输出语义等价
- [ ] 签名校验通过（`codesign --verify --strict`），签名顺序为内层 helper 先、App 根后，未使用 `--deep`
- [ ] 单测覆盖 JSON 形状、退出码、错误码映射；真实 HAL 只读测试不写系统默认
- [ ] `swift build` 零警告、`swift test` 全绿

## Blocked by

None (can start immediately)

## Resolution

（closed 2026-10-24）实现见 `Sources/VoiceInputCore/CLI.swift`（解析/执行/编码）+ `Sources/VoiceInputCLI/main.swift`（6 行接线）+ `scripts/bundle-app.sh`（复制与 inside-out 签名）。

**落点修订**：解析与编码放进 `VoiceInputCore`，可执行目标只调唯一公开入口 `CLIEntry.run(arguments:appVersion:)`。规格原计划把逻辑写在 `main.swift`，但 executable target 无法被 `swift test` 驱动，那样 JSON 形状与退出码就只能靠手工验证。规格 §B 已同步修订。

**真机结果**（`build/VoiceInput.app/Contents/MacOS/voiceinput-cli`）：

| 命令 | 结果 |
|---|---|
| `version` | `{"appVersion":"1.0.0","protocol":1}`，退出 0 |
| `list` | 8 台设备、HAL 原序、`isDefault` 只有一处表达、无顶层 `defaultDeviceID` |
| `list --pretty` | 同语义、2 空格缩进 |
| `set-default 93` | 回读后 `isDefault: [93]`；独立探针读 HAL 亦为 93；随后 `set-default 177` 复原 |
| `set-default 99999` | 退出 4 + `device_not_found` |
| 无参数 / 未知子命令 | 退出 2 + `bad_usage`（且遵守 `--pretty`） |

签名链：helper 先签、`.app` 根后签，`codesign --verify --strict` 两层都通过，未使用 `--deep`。

**测试**：`swift test` **64 tests / 10 suites 全绿**（新增 17 条 CLI 契约测试：解析、JSON 形状、同名序号、回读语义、四类错误码、`--pretty` 等价性）。

**review 后修掉的问题**（Standards 与 Spec 两个 sub-agent 各自独立指出，修完补了 4 条回归测试）：

1. **空列表曾被当成成功**：HAL 枚举失败与「真的没有设备」都表现为 `[]`，原实现输出 `{"devices":[]}` 并退出 0，违反契约「枚举失败 → `hal_error`」。现在三种读失败（枚举为空 / 读不到默认 / 默认 id 不在枚举结果里）统一 `hal_error` 退出 3——没有可切目标时，报错比给一份无勾选列表诚实。
2. **`--pretty` 在用法错误时被丢掉**：`usageError` 现在携带 `pretty`；同时修掉「`--pretty` 放在首位被判成用法错误」与注释不符的问题。
3. **`displayNames` 误改 `public`**：CLIRunner 本就在同一 module，已恢复 internal（原改动是多余的 API 扩散）。
4. **public 符号过多**：从 5 个收敛到 1 个（`CLIEntry`）。
5. **编码失败会输出空行 + 退出 0**（吞错）：改为退化成固定错误 JSON + 退出 3。
6. **`bundle-app.sh` 的 helper 校验**挪到步骤 2，与主二进制共用同一套候选清单提示。
