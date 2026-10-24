---
id: "0025"
title: "首发分发包：安装脚本 + Release 产物"
labels: [ready-for-agent]
status: open
claimed-by: ""
blocked-by: ["0024"]
---

## Parent

[0023 VoiceInput CLI 契约 + Raycast 插件规格](0023-voiceinput-raycast-spec.md)（§D 分发与发布）

## What to build

让**别人（以及清掉 App 的自己）能用一条命令装好**含 helper 的 VoiceInput，而不是被 Gatekeeper 拦在门外。

- `install.sh`：解析最新 release → 下载 zip 与 `.sha256` → 校验 → 解压到 `~/Applications/VoiceInput.app`（替换旧的）→ `xattr -cr` 清隔离 → 打开一次；任一步失败即非零退出并说清原因。`VERSION=v1.0.0` 可覆盖以规避 API 限流。
- `release.sh`：构建 → 打包 → 生成 zip 与 sha256 → 打印可复制的 `gh release create` 命令（不自动 tag/push/上传）。
- 主仓转 public、打首个 tag、发布首版 release，使安装命令真正可用。

## Acceptance criteria

- [ ] 删掉 `~/Applications/VoiceInput.app` 后，跑 `curl -fsSL …/install.sh | bash` 能装好并可直接执行 helper
- [ ] 校验和不匹配、网络失败、解压失败三种情况都以非零退出并给出可读原因
- [ ] `install.sh` 结束后 App 位于 `~/Applications`，无 quarantine 属性，无「已损坏」拦截
- [ ] `release.sh` 产出 `VoiceInput-<version>.zip` + `.sha256`，并打印正确的 `gh release create` 命令
- [ ] 主仓已 public，首个 release 的资产可被安装脚本实际取到
- [ ] 重跑 `install.sh` 幂等（覆盖安装不残留旧内容）
- [ ] 发布步骤清单（tag → release → 校验下载）写进仓库文档，供下次发版照做

## Blocked by

- [helper CLI 落地：voiceinput-cli 三命令与打包签名](0024-helper-cli.md)
