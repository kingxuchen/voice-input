---
id: "0015"
title: "Raycast 扩展平台能力与 Store 发布要求核查"
labels: [wayfinder:research]
status: closed
claimed-by: "research-0015"
blocked-by: []
---

## Parent

[0014 Raycast 音频输入切换插件 — Wayfinder 地图](0014-raycast-plugin-map.md)

## Question

查清 Raycast 扩展的运行环境与发布约束，为「插件通过 CLI 子命令调用伴侣 App」这条已被选定的路线排雷：

1. **运行环境**：扩展跑在什么进程/运行时？能否 `child_process.execFile` 调用任意本地可执行文件（有无白名单、权限提示、沙箱限制）？能否读取任意绝对路径、读取 stdout/stderr、设置超时与退出码？
2. **Store 审核政策**：扩展依赖「用户自行安装的伴侣 App / 本地二进制」是否被允许？审核是否要求扩展开箱即用、不许依赖外部安装？官方对 `preferences`（用户填写路径）这类兜底的态度？
3. **命令与 UI 约束**：命令数量、`List` + `ActionPanel` 的既有惯例；`closeMainWindow` / `showHUD` 的行为；`useCachedPromise` / `Cache` API 的缓存语义（本案必须避免陈旧数据）。
4. **Store 资产与流程**：必需文件（`package.json` 字段、icon 规格、README、截图、分类）、`ray lint` / `ray build` / `npm run publish` 的实际步骤与审查周期。
5. **本地开发回路**：`npm run dev`（`ray develop`）如何加载本地扩展、能否在无人工点击的情况下跑通命令、是否有可脚本化的测试手段。

产出：`research/raycast-extension-platform.md`（结论先行 + 官方文档链接与核对日期 + 对本案的具体含义 + 未解风险）。只写这一个文件，不改其它文件。

## Resolution

（closed 2026-10-24）报告：[research/raycast-extension-platform.md](../research/raycast-extension-platform.md)（396 行，含信源与核对日期）

1. **进程能力**：Raycast 托管单个 Node.js 子进程，扩展跑在独立 V8 isolate，无额外文件系统/进程沙箱；`child_process.execFile` / `spawn` 可执行任意绝对路径，支持 `timeout`（SIGTERM）、`maxBuffer`、退出码与 stdout/stderr 分捕。→ CLI 子命令路线成立。
2. **Store 允许伴侣 App**：在架先例 Tailscale（默认执行 `/Applications/Tailscale.app/Contents/MacOS/Tailscale` + `tailscalePath` 偏好兜底）、AeroSpace（扫 Homebrew 路径 + `List.EmptyView` 重试/下载引导）、Brew、Docker。红线：不捆绑不透明二进制；未安装时**严禁未捕获异常崩溃**，必须 `EmptyView` + ActionPanel 引导；偏好路径 `required: false`。
3. **缓存红线（与主人要求冲突的点）**：`useCachedPromise` / `useExec` / `useCachedState` 遵循 RFC 5861 SWR，**跨运行把上次结果落盘并在启动时先吐旧数据**；`Cache` 同样持久化。→ 个案全案封杀这四个 API，改用 `usePromise`（无 initialData）或 `useState` + `useEffect`，挂载即调 CLI，`isLoading` 期间不渲染空态（避免 EmptyView 闪烁）。
4. **Store 资产与流程**：MIT、真实 Raycast 账号 author、512×512 PNG 图标、≥3 张 16:10 截图（`metadata/`）、`CHANGELOG.md`（Keep a Changelog + `{PR_MERGE_DATE}`）、说明伴侣 App 依赖的 `README.md`；`ray lint` → `ray build` → `npx ray publish`（自动向 `raycast/extensions` 提 PR），macOS runner CI + 人工审核，周期约 2 个工作日到 1–2 周。
5. **开发与测试回路**：`ray develop` 热重载挂载本地 Raycast；`raycast://` deeplink 首次拉起有确认弹窗（不适合无头自动化）；官方无 `ray test`，Store 通行做法是 `devDependencies` 加 **Vitest** + `vi.mock("@raycast/api")` 做协议/状态逻辑单测。

**对本图的输入**：
- 0018 的默认探测路径要指向 helper（`Contents/MacOS/voiceinput-cli`），不是 App 主二进制（与 0017 定的契约一致；报告举例用主二进制只是 Tailscale 式示意）。
- 0018 可考虑项副标题显示传输类型（`kAudioDevicePropertyTransportType`），但仅作展示——0004 已裁决排序不得按传输类型分组。
- 0021 原型必须实测三件事：`execFile` 在扩展进程内可用、`showHUD` 是否如文档所述自动关窗、Vitest mock 能否脱离 GUI 跑。
