---
id: "0025"
title: "首发分发包：安装脚本 + Release 产物"
labels: [ready-for-agent]
status: closed
claimed-by: "impl-0025"
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

## Progress（2026-10-24，代码部分完成）

- `scripts/install.sh`：解析 latest release（`VERSION=v1.0.0` 可覆盖）→ 下载 zip + `.sha256` → `shasum -c` 校验 → `ditto` 解压 → 替换 `~/Applications/VoiceInput.app` → `xattr -cr` → helper 自检 → `open`。`BASE_URL` 可指向镜像/本地目录（离线测试用）。
- `scripts/release.sh`：从 `bundle-app.sh` 读 `VERSION`（唯一来源）→ 构建 → `ditto` 打 zip → 生成 sha256 → 打印 `git tag` 与 `gh release create` 命令，不自动上传。
- 本机实测（`BASE_URL=file://…/dist`，先删 App）：

| 场景 | 结果 |
|---|---|
| 正常安装 | ✅ 落到 `~/Applications`，helper `version` 返回 1.0.0，无 `com.apple.quarantine` |
| 重跑（幂等） | ✅ 覆盖安装成功 |
| 校验和不匹配 | ✅ 非零退出 +「校验和不匹配，已中止」 |
| 版本不存在 | ✅ 非零退出 +「下载失败: …」 |

**未完成（需仓库所有者执行，我未越权改动仓库可见性）**：
1. 主仓 `kingxuchen/voice-input` 转 public；
2. `git tag v1.0.0 && git push origin v1.0.0`；
3. `gh release create v1.0.0 dist/VoiceInput-1.0.0.zip dist/VoiceInput-1.0.0.zip.sha256 --repo kingxuchen/voice-input`；
4. 发布后用 `VERSION=v1.0.0 bash scripts/install.sh`（不带 `BASE_URL`）跑一次真实下载自检。

产物已在 `dist/`（zip 1.4 MB + sha256），执行上面三条命令即可发版。

## Resolution

（closed 2026-10-24）主仓已 public，`v1.0.0` 已发布，安装链路用**真实公网地址**跑通。

**发布结果**

- tag `v1.0.0` → `github.com/kingxuchen/voice-input/releases/tag/v1.0.0`
- 资产：`VoiceInput-1.0.0.zip`（1,407,080 B）+ `.zip.sha256`（87 B）
- `raw.githubusercontent.com/kingxuchen/voice-input/main/scripts/install.sh` 返回 200

**真机验证（临时 HOME，模拟干净机器，全部走公网）**

| 场景 | 结果 |
|---|---|
| `VERSION=v1.0.0 bash install.sh` | ✅ 下载 → 校验 → 原子安装 → helper `version` 返回 1.0.0 |
| 不带 `VERSION`（自动取最新） | ✅ 解析到 v1.0.0 并安装成功 |
| 安装产物隔离属性 | ✅ 无 `com.apple.quarantine`（Gatekeeper 不拦） |
| 校验和损坏 / 版本不存在 / 查不到最新版 | ✅ 各自非零退出 + 可读原因 |

**发布过程中发现并修掉的一个真问题**：原实现用 `api.github.com/releases/latest` 解析版本，未认证限流 **60 次/小时/IP**，且发版后立刻查询会短暂 404（我第一次自检就撞上了）。改成走 `github.com/<repo>/releases/latest` 的 HTML 重定向取 tag——无限流、无竞态。

**发布流程文档**：`docs/RELEASING.md`（改版本 → 本地门禁 → `release.sh` → tag/release → 发布后自检 → 扩展侧）。

**遗留（不在本票范围）**：Homebrew tap 见 0029。
