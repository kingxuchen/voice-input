---
id: "0020"
title: "Store 发布与伴侣 App 分发决策：用户怎么装上 VoiceInput"
labels: [wayfinder:grilling]
status: closed
claimed-by: "mainline-session"
blocked-by: ["0015", "0016"]
---

## Parent

[0014 Raycast 音频输入切换插件 — Wayfinder 地图](0014-raycast-plugin-map.md)

## Question

主人已定「发布 Raycast Store」，而插件依赖用户自行安装的 VoiceInput.app（当前 ad-hoc 签名、个人自用）。基于 [0015](0015-raycast-extension-platform-store.md)（平台与审核政策）与 [0016](0016-companion-app-distribution.md)（分发与签名路径）的研究结论，拍板：

1. **分发路线**：GitHub Release 直发 zip/dmg ／ Homebrew Cask ／ Developer ID + 公证 ／ 暂不公开分发（仅本人可用，代码按 Store 规范写）。给出成本（钱、账号、每版工时）与用户步骤数对比后择一。
2. **缺 App 时的用户动线**：空态文案 + 「复制安装命令」的确切命令文本（如 `brew install --cask voiceinput` 或 `xattr -d com.apple.quarantine …`）+ 是否提供「打开下载页」动作。
3. **审核风险预案**：若审核以「依赖未公证的第三方 App」为由拒绝，退路是什么（改为引导手动安装？改为 Store 外自用？）。
4. **版本演进**：App 升级与协议版本（`protocol`）同进同退的策略；插件如何提示"App 太旧"；发布节奏（先发 App 还是先发扩展）。
5. **是否需要自动化**：无 CI 前提下，发布检查清单（构建 → 组装 → 签名 → 打包 → 上传 → 更新下载命令）是否要脚本化。

产出：Resolution 记录五条结论；若结论要求改 App 签名/分发脚本，开实现票（图外，由 to-tickets 承接），并在本图只留契约性结论。

## 输入（0015 / 0016 均已关）

- 分发侧：ad-hoc 网络直发在 macOS 15+ 被 Gatekeeper 封死；Cask 无法绕过隔离（`--no-quarantine` 已删、Cask 主动打隔离）；$0 可行 = **自建 tap 的 Formula 本地编译**（无隔离）或 **`curl|bash` 脚本内 `xattr -cr`**；$99 Developer ID + 公证为终局。详见 [0016 Resolution](0016-companion-app-distribution.md)、`research/companion-app-distribution.md`。
- 审核侧：Store 允许依赖 Homebrew 等外部安装的伴侣工具，红线是不捆绑不透明二进制、未安装时不崩溃、路径偏好 `required: false`；详见 [0015 Resolution](0015-raycast-extension-platform-store.md)。
- 待决仍是「选哪条 + 安装命令的确切文本 + 拒稿预案 + 发布节奏」，不要重问平台是否允许。

## Resolution

（待定）

## Resolution

（closed 2026-10-24，6 项全部按推荐定稿；主人确认「后续自行把仓库公开」。）

### 1. 仓库公开策略

- `kingxuchen/voice-input` 从 PRIVATE 转 **public**（主人后续执行）。公开后才能用 raw 脚本地址与 GitHub Releases。
- 事实：Raycast Store 的提交通道是向公共 `raycast/extensions` 提 PR，**扩展源码必然公开**，与主仓是否公开无关。
- 私有兜底：若暂时不公开，安装命令全部失效，只能本地自用——因此公开是发布前置条件，写进 SPEC 的 prerequisites。

### 2. 阶段一主路线（$0）

- **主：`curl | bash` 安装脚本**（curl 系统自带，零前置）。
- **备：Homebrew Formula**（自建 tap `kingxuchen/tap`，本地源码编译，无隔离属性）。
- 阶段二（触发条件：想要零终端体验，或 Store 审核施压）：$99 Developer ID + 公证 dmg，扩展侧只换命令文本。

### 3. 安装命令文本（空态动作用）

| 动作 | 文本 |
|---|---|
| `Copy Install Command` / `复制安装命令`（Primary） | `curl -fsSL https://raw.githubusercontent.com/kingxuchen/voice-input/main/scripts/install.sh \| bash` |
| `Copy Homebrew Command` / `复制 Homebrew 命令` | `brew install kingxuchen/tap/voiceinput` |
| `Open Installation Guide` / `打开安装指南` | `https://github.com/kingxuchen/voice-input#install` |

- 脚本地址钉 `main`（文本不随版本变），脚本内部再解析最新 release。

### 4. Release 产物与 `scripts/install.sh` 契约

- 每版附件：`VoiceInput-<version>.zip`（`ditto -c -k --keepParent`，保住签名）+ `VoiceInput-<version>.zip.sha256`。
- `install.sh`（`set -euo pipefail`）步骤：
  1. 解析 latest release（GitHub API；`VERSION=v1.0.0` 可覆盖，规避匿名 API 限流）；
  2. 下载 zip 与 `.sha256` 到临时目录，`shasum -a 256 -c` 校验；
  3. `ditto -x -k` 解压 → 替换 `~/Applications/VoiceInput.app`（先删旧）；
  4. `xattr -cr ~/Applications/VoiceInput.app`（清 quarantine）；
  5. `open` 一次并打印结果摘要；
  6. 任一步失败 → 非零退出 + 明确原因，不静默继续。

### 5. 版本演进与发布顺序

- App 先行：bundle 版本 `1.0.0`、helper `protocol: 1`；版本常量单一来源 = `scripts/bundle-app.sh` 的 `VERSION`（helper 的 `version` 输出同源）。
- 再提 Store 扩展；扩展声明最低 `protocol`。
- App 升级 = 重跑同一条安装命令；「VoiceInput 版本过旧」文案里直接带这条命令。

### 6. 拒稿预案与自动化边界

- Store 以「依赖外部安装」拒稿 → 扩展退回本地自用（`ray develop`），App 分发不回滚。
- 不引入 CI。新增两个脚本：
  - `scripts/release.sh`：`bundle-app.sh` → ditto zip → sha256 → 打印可复制的 `gh release create v<version> …` 命令（不自动 push/tag）。
  - `scripts/install.sh`：见上。
- 手工步骤（tag、`gh release create`、tap 更新）写进 SPEC 发布清单，不脚本化到会误伤的程度。

### 遗留

- 仓库公开、建 `kingxuchen/tap`、首个 Release 属发布执行动作，不在本图内（写进 SPEC prerequisites/release checklist）。
