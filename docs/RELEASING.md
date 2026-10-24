# 发布清单

一次性人工步骤，没有 CI。按顺序做，每步都有可观察的结果。

## 0. 前置（只做一次）

- 主仓 `kingxuchen/voice-input` 必须是 **public**——安装脚本走 `raw.githubusercontent.com` 与 GitHub Release，私有仓取不到。
- 本机 `gh` 已登录（`gh auth status` 通过）。

## 1. 改版本号

版本唯一来源：`scripts/bundle-app.sh` 里的 `VERSION`。改它，helper 的 `version` 输出会跟着变（同一来源）。

## 2. 本地门禁

```bash
swift build && swift test          # 64 tests / 10 suites
cd raycast && npx vitest run       # 25 tests
npx ray lint                       # 除 author 外应全绿
```

## 3. 打包产物

```bash
scripts/release.sh
```

产出 `dist/VoiceInput-<version>.zip` 与 `.zip.sha256`，并打印下面几条命令（不会自动上传）。

## 4. 打 tag 并发布

```bash
git tag v<version> && git push origin v<version>
gh release create v<version> \
    dist/VoiceInput-<version>.zip \
    dist/VoiceInput-<version>.zip.sha256 \
    --repo kingxuchen/voice-input --title 'VoiceInput <version>' --notes '见 CHANGELOG'
```

## 5. 发布后自检（必须做，否则用户装不上你也不知道）

```bash
# 1) 真实下载路径（不带 BASE_URL）
rm -rf ~/Applications/VoiceInput.app
VERSION=v<version> bash scripts/install.sh

# 2) 装完能不能用
~/Applications/VoiceInput.app/Contents/MacOS/voiceinput-cli version
~/Applications/VoiceInput.app/Contents/MacOS/voiceinput-cli list
```

期望：安装无 Gatekeeper 拦截；`version` 返回本次版本与 `protocol: 1`；`list` 列出本机输入设备。

## 6. 扩展侧（仅当 `protocol` 或界面有变）

```bash
cd raycast
npx ray lint && npm run build
npx @raycast/api@latest publish   # 向公共 raycast/extensions 提 PR
```

协议演进规则：**加字段不 +1**，破坏性变更才 +1。扩展声明自己支持的最低 `protocol`；
协议更高 → 提示「插件太旧」，协议更低 → 提示「VoiceInput 版本过旧」。

## 已知边界

- Apple Silicon 上 ad-hoc 签名可用；脚本负责 `xattr -cr` 清隔离。若要零终端体验，需 Developer ID + 公证（阶段二）。
- Homebrew tap 是脚本之外的备选路径，见 `.issues/0029-homebrew-tap.md`。
