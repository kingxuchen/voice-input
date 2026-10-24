---
id: 0014
title: "Raycast 音频输入切换插件 — Wayfinder 地图"
labels: [wayfinder:map]
status: closed
---

## Destination

定稿两份可照做的文档——**VoiceInput 对外接口契约**（CLI 子命令 + JSON 协议 + 退出码 + 版本握手）与 **Raycast 插件规格**（命令形态/UI/错误态/偏好设置/Store 发布要求），使后续编码票不需再做决定即可落地。路线清晰即关图，编码不在本图内。

## Notes

- 主人诉求：Raycast 插件能看设备列表、能改当前选中的音频输入来源；**每次获取都必须现读 macOS 最新输入源，禁止旧数据**；旧应用展开菜单时同样必须是最新音源与当前选中。
- 第一轮 grilling 定局（2026-10-24）：
  1. 地图交付 = **契约 + 插件规格**（编码另行拆票）。
  2. 接口形态 = **(a) CLI 子命令**：同一 `.app` 内的可执行文件，每次调用现读 HAL，无缓存面，App 不必常驻运行。
  3. 读取时机 = **触发时调用**（Raycast 命令启动、菜单打开），不做轮询。
  4. 交付方式 = **发布 Raycast Store**（不只是本地自用）——由此引入对伴侣 App 公开分发与审核政策的硬约束。
  5. 代码落位 = 仓库内新建 `raycast/` 独立 TypeScript 工程。
  6. 「旧应用菜单打开也要最新」= 必须做到（0013 已实现，本图负责回归验证，并把「插件切换后菜单跟随」纳入验收）。
  7. CLI 缺失时插件提示安装 VoiceInput + 可复制的安装命令，不伪造列表。
- 第二轮 grilling 定局（2026-10-24）——细化到可实现，细则写在对应票的 Question 里：
  1. 契约骨架：`voiceinput-cli`（独立 SwiftPM executable，复用 `VoiceInputCore`，装入 `.app/Contents/MacOS/`）；`list --json` / `set-default <id> --json` / `version --json`；`{"protocol":1,"devices":[{id,name,isDefault}],"defaultDeviceID"}`；退出码 `0/2/3/4`；错误走 stderr；`set-default` 返回回读状态。
  2. 插件 UX：一条命令，List 项=设备、标「当前默认」；`Enter` 切换 → `closeMainWindow()` + `showHUD`；`⌘R` 重读、`⌘C` 复制名、`⌘⇧O` 声音设置、`⌘⇧V` 打开 VoiceInput；偏好设置 `cliPath`（自动探测 `/Applications`、`~/Applications`）；缺 CLI → 空态 + 复制安装命令。
  3. 语言：界面与设置项**中英双语**；Store 元数据以英文为准（平台机制由 [0015](0015-raycast-extension-platform-store.md) 确认）。
  4. 竞态：不持久化设备 ID；退出码 4 → 自动重读 + HUD「设备已断开，列表已刷新」；列表保持 HAL 原序（沿用 0004）。
  5. 验收：Swift 单测 + 真机 `npm run dev` 手验清单（含「插件切换后菜单栏勾选跟随」）。
- 建图时核查的现状：`Sources/` 无任何跨进程接口（grep 无 URL scheme / CLI 参数 / XPC / socket / 状态文件）；`MenuOpenObserver` + `AudioDeviceManager.refresh()` 已覆盖菜单打开重读设备与默认设备；仓库无 Raycast 脚手架（无 `package.json`）；分支 `raycast-plugin` 干净。
- 已关旧图：[0001 菜单栏输入切换器地图](0001-menu-bar-input-switcher-map.md)（v1 已落地，见 0006–0013）。
- HITL 票加载 skills：grilling、domain-modeling；研究票加载 research。
- 追踪器约定（本地 markdown）：`.issues/` 每票一文件；front-matter `status: open|closed`、`claimed-by`、`blocked-by`（票 id 列表）；答案写进票内 `## Resolution` 后置 closed，并在本图 "Decisions so far" 追加一行；研究产物放 `research/*.md`（仓库无远端，不开分支）。一张票一个 session（研究票可并行）。

## Decisions so far

- [汇总定稿 SPEC](0022-spec-assembly.md)（closed 2026-10-24）：产出 [0023 VoiceInput CLI 契约 + Raycast 插件规格](0023-voiceinput-raycast-spec.md)（`wayfinder:spec` + `ready-for-agent`）——CLI 契约逐字可抄、插件规格含两个真机坑的修法、分发三条安装命令与 `install.sh`/`release.sh` 契约、前置条件（主仓 public / 真实 Raycast author / 首发 Release / ≥3 截图）、10 条真机手验清单与风险表。**地图关闭**：Destination「契约 + 插件规格定稿」达成，编码由后续 to-tickets 拆解，不属本图。
- [插件骨架原型](0021-raycast-skeleton-prototype.md)（closed 2026-10-24）：`raycast/` 里真机跑通核心闭环（build ✅ / vitest 8 例 ✅）。四条实证：`execFile` 无沙箱可用；**`showHUD` 自动关主窗口**（261–329 ms，不必补 `closeMainWindow`）；列表信息密度够（8 台单屏 + `当前` 标签）；**`Intl` 判语言不可靠**——Raycast 把中文系统报成 `en-CN-…`，改用 `defaults read -g AppleLanguages`。另抓到一个必踩坑并修掉：**Raycast 会把根搜索查询词注入命令搜索框**，导致设备列表变 `No Results`；最终做法 = 丢弃挂载后 400 ms 内的 `onSearchTextChange` 推送（受控空串与 `undefined` 初值都盖不住）。验收全绿：列表/`当前`/`Enter` 切换/`⌘R` 重读外部改动/缺 CLI 空态/中文文案/`device_not_found` 退出码。遗留：`author` 需真实 Raycast 账号、截图需 ≥3 张、原型 helper 是 /tmp 桩未入库。
- [菜单打开新鲜度真机复验](0019-menu-freshness-baseline.md)（closed 2026-10-24）：**判定现行为已满足「每次打开都最新」，无需补代码**。真机实测：外部改默认后立刻点开菜单，三次切换（177→93 / 172→149 / 149→172）勾选**每次都直接是新值**；更关键的是菜单**保持打开**期间外部改默认，勾选当场就跟随（HAL 属性监听 + 50ms 防抖，非轮询），不存在说假话的时间窗；菜单打开路径刷新耗时设备+默认 **2.8–6.6 ms**、登录项 **2.6–7.8 ms**（冷启动首次枚举 190–270 ms 只影响一次性进程，印证 0017 的 2000ms 超时有安全余量）；热插拔仍由 47 个单测覆盖，未做真机拔插。
- [Store 发布与伴侣 App 分发决策](0020-store-publish-distribution-decision.md)（closed 2026-10-24）：主仓 `kingxuchen/voice-input` 转 public（发布前置）；阶段一 $0 = **`curl|bash` 脚本为主**（`curl -fsSL https://raw.githubusercontent.com/kingxuchen/voice-input/main/scripts/install.sh | bash`）+ **自建 tap 的 Formula 为辅**（`brew install kingxuchen/tap/voiceinput`），阶段二再上 $99 公证；Release 附件 `VoiceInput-<version>.zip` + `.sha256`，`install.sh` 校验→解压到 `~/Applications`→`xattr -cr`→`open`，失败非零退出；版本单一来源 = `bundle-app.sh` 的 `VERSION`，App 先行、扩展后发；拒稿则扩展退回本地自用、分发不回滚；只加 `scripts/{release,install}.sh`、不引 CI。
- [插件 UX 与 Store 规格定稿](0018-raycast-plugin-ux-store-spec.md)（closed 2026-10-24）：**一条 `view`/List 命令** `switch-input`（标题 `Switch Audio Input`）——输入即见设备列表、选中 `Enter` 即切换，不做第二条命令；项 = `displayName` + 默认项 `Current` 标签/勾选，统一 `Icon.Microphone`、不显 id、不排序列；动作 `↵` 切换 / `⌘R` 刷新 / `⌘C` 复制名 / `⌘⇧O` 声音设置 / `⌘⇧V` 打开 App；`showHUD` 反馈（不自动关窗则补 `closeMainWindow`，交 0021 实测）；错误码与超时各有落点，`ENOENT` 走安装空态（复制安装命令/指南/重试/打开偏好）；manifest 静态英文 + 自有文案按系统语言 en/zh；禁用 `useCachedPromise`/`useExec`/`useCachedState`/`Cache`，加载中不渲染空态；Store 资产 512² 图标 + 3 张 16:10 截图 + 双语 README + `{PR_MERGE_DATE}` CHANGELOG；`raycast/` 结构 `src/switch-input.tsx` + `src/lib/{cli,types,i18n}.ts`，`execFile` 只在 `cli.ts`。
- [接口契约定稿](0017-cli-contract.md)（closed 2026-10-24）：helper = `.app/Contents/MacOS/voiceinput-cli`（独立 target，不启动 NSApp）；子命令 `list` / `set-default <id>` / `version`，**JSON 恒输出**（`--pretty` 仅供人肉调试）；成功形状 `{"protocol":1,"devices":[{id,name,displayName,isDefault}]}`（`set-default` 回读后返回完整新状态，无冗余顶层 `defaultDeviceID`；序号规则只留在 Swift 的 `displayName`）；错误走 stdout 结构化 `{protocol,error:{code,message}}` + stderr 人话，退出码 `2 bad_usage` / `3 hal_error`（枚举或默认读取失败，宁可报错不说谎）/ `4 device_not_found|switch_failed`；`protocol` 仅破坏性变更 +1，三种不匹配态各有落点；插件预算 timeout 2s + SIGTERM→SIGKILL、maxBuffer 1MB；打包先签 helper 再签 app 根、禁 `--deep`；不落盘缓存、不做 watch/IPC。
- [伴侣 App 公开分发与签名路径核查](0016-companion-app-distribution.md)（closed 2026-10-24）：ad-hoc 网络直发在 macOS 15+ 已被 Gatekeeper 封死（右键绕过移除）；Homebrew Cask 也救不了（无 `quarantine: false`、`--no-quarantine` 已删、Cask 主动打隔离，本机 7.0.10 源码复核）；$0 最小可行 = 自建 tap 的 **Formula 本地编译**（无隔离属性）为主、`curl|bash` + `xattr -cr` 为备，日后 $99 公证 dmg 平滑升级；Raycast Store **允许**外部伴侣 App（禁捆绑不透明大二进制），AeroSpace 范式 = 多路径探测 + `customBinaryPath` 偏好 + `EmptyView`+ActionPanel 兜底；`~/Applications` 对脚本更友好，Core Audio 设备控制不触发 TCC，公证须 inside-out、禁用 `codesign --deep`。报告：research/companion-app-distribution.md
- [Raycast 扩展平台能力与 Store 发布要求核查](0015-raycast-extension-platform-store.md)（closed 2026-10-24）：扩展在 Node 运行时、无额外沙箱，`execFile` 可执行任意绝对路径（timeout/退出码/stdout 均可控）→ CLI 路线成立；Store **允许**伴侣 App（Tailscale / AeroSpace / Brew / Docker 先例），红线是不捆绑不透明二进制、未安装时不得崩溃、路径偏好 `required: false`；**`useCachedPromise`/`useExec`/`useCachedState`/`Cache` 全部封杀**（SWR 跨运行落盘、先吐旧数据），改 `usePromise` 且加载中不渲染空态；Store 资产 = MIT + 512² 图标 + ≥3 张 16:10 截图 + CHANGELOG + README，`ray lint`→`ray build`→`npx ray publish` 提 PR（2 日–2 周）；`ray develop` 热重载可用，官方无 `ray test`，用 Vitest + `vi.mock("@raycast/api")`。报告：research/raycast-extension-platform.md

## Not yet specified

- 「声音设置」深链在多语言系统与 macOS 大版本间的可靠性
- 未来是否要把输出设备也纳入同一 CLI 契约（本图不做，仅记录契约是否预留）

## Out of scope

- 输出设备切换（沿用旧图裁决：本线只做输入）
- 插件内直接实现 Core Audio（已否决：必须经旧应用接口）
- Raycast AI / 其他 Raycast 集成面
- 旧应用的 UI 改造（除新鲜度验证确需的最小修补）
- Windows / Linux 支持
