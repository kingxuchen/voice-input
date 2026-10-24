---
id: "0029"
title: "Homebrew tap：源码编译安装的备用路径"
labels: [ready-for-agent]
status: open
claimed-by: ""
blocked-by: ["0025"]
---

## Parent

[0023 VoiceInput CLI 契约 + Raycast 插件规格](0023-voiceinput-raycast-spec.md)（§D 分发与发布）

## What to build

给 Homebrew 用户一条**不经 Gatekeeper 拦截**的安装路径：`brew install kingxuchen/tap/voiceinput` 从源码本地编译，产物没有 quarantine 属性，装完 helper 可直接被插件调用。这是脚本安装之外的备选，不是阻塞项。

## Acceptance criteria

- [ ] 自建 tap 仓存在，`brew install kingxuchen/tap/voiceinput` 在干净环境可完成安装
- [ ] 安装产物落在标准位置且 helper 可执行，无「已损坏」拦截
- [ ] `brew uninstall` 能干净移除，不残留 App 或 helper
- [ ] tap 的 `brew audit` 通过（或明确记录无法通过的原因与取舍）
- [ ] 插件空态里的 Homebrew 命令与实际可用命令一致

## Blocked by

- [首发分发包：安装脚本 + Release 产物](0025-install-and-release.md)
