---
id: "0016"
title: "伴侣 App 公开分发与签名路径核查"
labels: [wayfinder:research]
status: closed
claimed-by: "research-0016"
blocked-by: []
---

## Parent

[0014 Raycast 音频输入切换插件 — Wayfinder 地图](0014-raycast-plugin-map.md)

## Question

本题只为一件事：**别人装上你的 Raycast 插件后，怎么把 VoiceInput.app 装到他们机器上并让 CLI 可被调用**。现有 App 是 ad-hoc 签名、个人自用（见 [0003](0003-swiftpm-app-bundling.md)、`scripts/bundle-app.sh`）。

1. **ad-hoc 直发的真实拦截**：下载得到 ad-hoc `.app` 后 Gatekeeper/quarantine 的具体行为（"已损坏，无法打开"？仅右键打开？`xattr -d com.apple.quarantine` 是否足够）；不同 macOS 版本（14 / 15 / 26）差异。
2. **分发渠道对比**：GitHub Release 直发 zip/dmg、Homebrew Cask（ad-hoc 可否定制 `quarantine: false` 之类）、Developer ID + 公证（费用、Apple 账号要求、`notarytool` 流程）、以及其他不花钱的可行路径。给出对本项目「个人自用、可能发布 Raycast Store」的最小可行方案。
3. **Raycast Store 侧的连带要求**：若审核要求"用户能一步装好"，哪些签名/分发状态才算达标；扩展里放下载链接、还是放"打开安装页"动作是通行做法。
4. **CLI 路径与安装位置**：`/Applications` vs `~/Applications` 对 Raycast 进程（非沙箱 Node）可执行性与 TCC 的影响；公证后的 helper 可执行文件是否需单独签名（inside-out 签名顺序）。

产出：`research/companion-app-distribution.md`（结论先行 + 官方文档链接与核对日期 + 对本项目的推荐路线 + 未解风险）。只写这一个文件，不改其它文件。

## Resolution

（closed 2026-10-24）报告：[research/companion-app-distribution.md](../research/companion-app-distribution.md)（389 行，含信源与核对日期）

1. **ad-hoc 网络直发不可用**：由网络下载的 zip/dmg 必被写 `com.apple.quarantine`；macOS 15 (Sequoia) 起 Apple 移除 Control-Click 绕过，未公证应用双击只给「移到废纸篓／取消」，要开得进「系统设置 › 隐私与安全性 › 仍要打开」+ 管理员密码。对 Raycast 用户不可接受。
2. **Homebrew Cask 救不了**：Cask DSL 无 `quarantine: false` stanza，`--no-quarantine` 已被官方删除；Cask 主动经 LaunchServices FFI 打隔离属性，官方政策拒收未过 Gatekeeper 审计的 cask。自建 tap 的 cask 同样被拦。
   - 本机复核（Homebrew **7.0.10**，`/opt/homebrew/Library/Homebrew`）：`grep -rn no-quarantine` **零命中**；`cask/quarantine.rb` 仍在 → 报告结论成立。
3. **最小可行（$0）双轨**：主路线 = 自建 tap 的 **Homebrew Formula 本地源码构建**（`brew install fanbingbing/tap/voiceinput`；产物由本地 `swift build` 生成，无隔离属性，Gatekeeper 零拦截，需 Xcode CLT）；备路线 = 一键 `curl … | bash` 脚本，下载预编译包后脚本内 `xattr -cr` 清隔离，装到 `~/Applications`。**两阶段演进**：日后花 $99/年拿 Developer ID + `notarytool` 公证 + `stapler` 装订，切正规 dmg；扩展侧只需改安装命令文本，不需重构。
4. **Raycast Store 允许外部伴侣 App**：官方要求「不捆绑体积大/不可审计的私有二进制」，允许调用系统二进制与 Homebrew 等已知包管理器装的外部工具。通行范式（AeroSpace 扩展）：多路径探测 + `customBinaryPath` 偏好兜底 + 未安装时 `<List.EmptyView>` + ActionPanel（复制安装命令／打开安装指南／打开扩展偏好／重试），严禁未捕获异常白屏。
5. **位置与签名边界**：`~/Applications` 对脚本更友好（当前用户可写、可清 quarantine、无需提权；`/Applications` 受 macOS 13+ App Management 保护）；Core Audio HAL 枚举/切换默认输入不建立采集流，**不触发 TCC 麦克风权限**；公证时须 inside-out 签名（先 nested helpers/frameworks，最后外层 bundle），签名禁用 `codesign --deep`（macOS 13 起 deprecated for signing），打包用 `ditto -c -k --keepParent`。

**对本图的输入**：0018 的「复制安装命令」文本与空态动作有了候选；[0020](0020-store-publish-distribution-decision.md) 需在 Formula / 脚本 / 公证三条中拍板（含 Raycast 审核文案口径）。
