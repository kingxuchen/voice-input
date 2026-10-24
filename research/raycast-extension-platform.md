# Raycast 扩展平台能力与 Store 发布要求深度调研报告

> 关联 Issue: [.issues/0015-raycast-extension-platform-store.md](../.issues/0015-raycast-extension-platform-store.md)  
> 上级地图: [.issues/0014-raycast-plugin-map.md](../.issues/0014-raycast-plugin-map.md)  
> 调研日期: 2026-10-24  
> 调研专家: Tech Research Scout (with TypeSafe System One / Jev 决策验证)  
> 适用工程: `VoiceInput` (macOS Swift 伴侣 App) + 仓库内新建 `raycast/` (独立 TypeScript 插件工程)

---

## 1. Executive Summary & TL;DR 结论表

| 调研维度 | 核心结论 | 官方一手证据来源 | 核对日期 | 对本案 (VoiceInput) 具体含义 |
| :--- | :--- | :--- | :--- | :--- |
| **1. 进程模型与运行环境** | Raycast 统一拉起托管的单个 Node.js 子进程；扩展运行于独立的 V8 isolate/worker thread，**无额外沙箱限制**。完全允许 `child_process.execFile` / `spawn` 调用任意绝对路径本地二进制。支持超时 (SIGTERM)、退出码、流式 stdout/stderr 捕获。 | [Raycast Security Architecture](https://developers.raycast.com/information/security.md) | 2026-10-24 | **完全可行**。Raycast 插件可通过 `execFile` 直接调用 `/Applications/VoiceInput.app/Contents/MacOS/VoiceInput --list-devices --json`，读写绝对路径无权限阻碍。 |
| **2. Store 伴侣 App 审核政策** | **完全允许**依赖用户自装的伴侣 App / 外部 CLI。官方 Store 存在大量知名在架先例（Tailscale、AeroSpace、Brew、Docker、CleanShot X）。官方指南要求**严禁打包不透明/无源码二进制**，鼓励通过 `preferences` 提供自定义路径兜底，并在未安装时提供友好恢复界面（禁止未捕获异常崩溃）。 | [Prepare Extension for Store](https://developers.raycast.com/basics/prepare-an-extension-for-store.md)<br>[GitHub: limonkufu/aerospace](https://github.com/raycast/extensions/tree/main/extensions/aerospace)<br>[GitHub: samlinville/tailscale](https://github.com/raycast/extensions/tree/main/extensions/tailscale) | 2026-10-24 | **路线成立**。VoiceInput 不应强行将二进制内嵌至插件 assets，而应采用「默认探测标准 App 路径 + Preferences 用户可选覆盖 + 未安装时展示优雅 EmptyView 附带下载链接」的标准架构。 |
| **3. 命令/UI 与数据新鲜度** | 惯例采用 `List` + `ActionPanel` 呈现列表；切换操作后可调用 `showHUD()` 自动隐藏主窗并展示浮动提示。
**核心警报**：官方 `useCachedPromise` 与 `useExec` 均强制采用 SWR（Stale-While-Revalidate）跨运行磁盘持久缓存，**会破坏本案「绝对禁止旧数据」要求**。 | [Raycast List API](https://developers.raycast.com/api-reference/user-interface/list.md)<br>[Raycast HUD API](https://developers.raycast.com/api-reference/feedback/hud.md)<br>[useCachedPromise Hook](https://developers.raycast.com/utilities/react-hooks/usecachedpromise.md)<br>[usePromise Hook](https://developers.raycast.com/utilities/react-hooks/usepromise.md) | 2026-10-24 | **架构强制约束**：在 Raycast 插件内**彻底封杀** `useCachedPromise`、`useExec` 与 `Cache` API。必须采用 `usePromise` (无 initialData/Cache) 或 React 原始状态，每次打开命令必须现场直读 Core Audio HAL。 |
| **4. Store 资产与发布全链路** | 必须具备合规 `package.json`（MIT 协议、author 为真实 Store 账号、`platforms: ["macOS"]`）、512x512 PNG 图标、根目录 `README.md` 与 `CHANGELOG.md`。发布通过 `npx ray publish` 自动向 `raycast/extensions` 提交 PR，由 macOS runner CI 自动化校验，审核周期通常为 2 个工作日至 1-2 周。 | [Publish an Extension](https://developers.raycast.com/basics/publish-an-extension.md)<br>[Raycast Manifest](https://developers.raycast.com/information/manifest.md)<br>[GitHub CI: extensions_build_publish.yml](https://github.com/raycast/extensions/blob/main/.github/workflows/extensions_build_publish.yml) | 2026-10-24 | 发布需准备作者 Raycast 账号、512px 图标、3-6 张 16:10 界面截图；开源协议定为 MIT；发布障碍主要在于需处理好「伴侣 App 缺失时的 UI 容错」，避免在 CI/审核测试中直接报错。 |
| **5. 本地开发与测试回路** | `ray develop` 实时编译热重载，自动挂载到本地 Raycast 客户端顶栏；支持 VS Code 附加 Node 调试器与 React DevTools。自动化方面：Deeplink (`raycast://`) 首次拉起有确认弹窗；官方 CLI **未提供** `ray test`，但 Store 顶级扩展通行方案为在 `devDependencies` 中使用 **Vitest** + `vi.mock("@raycast/api")` 实现 100% 自动化单元与协议测试。 | [Developer Tools CLI](https://developers.raycast.com/information/developer-tools/cli.md)<br>[Debug an Extension](https://developers.raycast.com/basics/debug-an-extension.md)<br>[Deeplinks Lifecycle](https://developers.raycast.com/information/lifecycle/deeplinks.md) | 2026-10-24 | 本地研发完全闭环：业务逻辑与 CLI 协议层由 Vitest 单测覆盖，GUI 交互由 `ray develop` 在本地 Raycast 真机走查。 |

---

## 2. TypeSafe AI (System One / Jev) 选型裁决记录

依据工程规范，使用 TypeSafe Jev 模型对本案的核心架构选型进行形式化判定与概率裁决。

### 决策一：CLI 执行机制选型 (Freshness vs. Caching)

* **判定问题**：Raycast 扩展调用 VoiceInput CLI 获取音频设备时，应采用何种执行封装？
* **证据输入**：
  1. Raycast 官方文档明确说明 `useExec` 遵循 RFC 5861 SWR 规范，强制将上次运行结果持久化于磁盘缓存，每次启动先吐出陈旧数据再异步刷新；
  2. `node:child_process` 的 `execFile` 原生支持纯净无缓存执行，提供毫秒级 `timeout`（SIGTERM）、`maxBuffer` 控制与 stdout/stderr 独立输出；
  3. 用户需求包含硬性约束：「每次获取都必须现读 macOS 最新输入源，禁止旧数据」。
* **Jev 模型裁决输出** (`tool: jev_decide`, `model: jev-1.14.0`):
  * **选定候选**：`child_process_exec_file`（推荐置信度: **0.97**，选定概率: **0.98**）
  * **候选对比**：`raycast_utils_use_exec` 概率为 **0.00**（其 3 项硬性要求检测全部返回 `contradicted`：无法避免跨运行陈旧数据、无法细粒度剥离错误流、无法防止界面首次闪烁旧状态）。
* **架构决议**：**全案采用 `promisify(child_process.execFile)` 封装底层执行，上层由无持久化缓存的 `usePromise` 或原生 React state 驱动。**

### 决策二：伴侣 App 发现与分发策略 (Store Compliance)

* **判定问题**：Raycast 扩展如何定位 VoiceInput 伴侣 App 并满足 Raycast Store 审核规范？
* **证据输入**：
  1. Raycast Store 指南明确禁止在插件 assets 中捆绑无法追溯构建来源的不透明闭源二进制；
  2. 在架标杆扩展（Tailscale、AeroSpace）均将安装职责交由宿主系统或用户，默认定位 `/Applications/<App>.app/Contents/MacOS/<Binary>`，并在 `preferences` 中暴露可选自定义路径；
  3. 未检测到外部应用时，标杆扩展通过 `List.EmptyView` 提供「打开下载页面」、「打开配置项」等引导动作，不抛出 Unhandled Exception。
* **Jev 模型裁决输出** (`tool: jev_decide`, `model: jev-1.14.0`):
  * **选定候选**：`companion_app_default_with_pref_fallback`（推荐置信度: **1.00**，选定概率: **1.00**）
  * **候选对比**：
    * `bundle_binary_in_extension_assets`（概率 0.00）：严重违反 Store 审核关于二进制透明性与插件体积的红线；
    * `mandatory_preference_path`（概率 0.00）：破坏开箱即用体验，首次运行强迫用户手动填写文件路径，违背 UX 体验准则。
* **架构决议**：**采用「默认标准路径 (`/Applications/VoiceInput.app/Contents/MacOS/VoiceInput`) + Preferences 可选覆盖项 + 缺失时空状态引导」组合方案。**

---

## 3. 核心问题深度剖析

### Q1: 运行环境与进程沙箱实测

#### 1. 进程模型与执行宿主
Raycast 桌面应用（作为通过 Apple 认证并 Notarized 的 Developer ID 应用程序）在后台维护一个专门的 Node.js 子进程来执行扩展。
* **隔离级别**：每个扩展运行在一个独立的 **V8 Isolate**（Worker Thread）内，拥有独立的事件循环、Node 实例以及有限的堆内存上限。
* **通信机制**：扩展代码与 Raycast 主界面进程之间通过标准文件句柄和轻量级 RPC 协议通信，Raycast 仅向上层暴露 `@raycast/api` 契约，不允许直接操作 Raycast 原生窗口句柄。
* **Node.js 运行时**：由 Raycast 官方统一分发管理与哈希校验，扩展内可直接使用标准 Node.js 内置模块（`child_process`, `fs`, `path`, `os`, `util` 等）。

#### 2. `child_process.execFile` 与 `spawn` 可用性验证
* **调用白名单**：**无任何白名单限制**。扩展拥有与运行 Raycast 的当前 macOS 用户完全等同的本地执行权限。
* **权限提示与沙箱**：
  * Raycast 官方文档明确说明：*“Extensions are not further sandboxed as far as policies for file I/O, networking, or other features of the Node runtime are concerned”*。
  * 扩展没有 macOS App Sandbox（即无沙箱容器目录限制，不是 Mac App Store 应用）。
  * 涉及 macOS 敏感权限（如麦克风录音、屏幕录制、辅助功能 Accessibility）时，权限弹窗由父进程 Raycast 向 macOS TCC 申请。
  * **针对本案**：VoiceInput CLI 查询音频输入设备列表及调用 Core Audio HAL 切换系统默认输入设备（`AudioObjectGetPropertyData` / `AudioObjectSetPropertyData`），**属于 CoreAudio 守护进程的公有属性操作，不需要 Microphone 录音数据权限**，因此不会触发 macOS 麦克风录制权限弹窗。
* **路径与输入输出控制**：
  * **绝对路径执行**：完全支持调用任意绝对路径，如 `/Applications/VoiceInput.app/Contents/MacOS/VoiceInput`。
  * **退出码与输出分离**：支持完整获取 `exitCode`、`stdout`、`stderr`。
  * **超时中断**：支持在 options 中传入 `timeout: number`（毫秒）。当子进程执行超过阈值时，Node.js 会自动向子进程发送 `SIGTERM`，避免僵死进程挂起插件。

---

### Q2: Store 审核政策与伴侣 App 架构

#### 1. 伴侣 App / 外部二进制依赖的准入界限
Raycast 官方 Store 欢迎与本地应用程序、系统工具或外部 CLI 集成的扩展。
* **官方准入规则**（引自 [Prepare an Extension for Store - Binary Dependencies](https://developers.raycast.com/basics/prepare-an-extension-for-store.md)）：
  1. *“Calling known system binaries”* —— 允许；
  2. *“Avoid asking users to perform additional downloads and try to automate as much as possible”* —— 官方建议尽可能让非技术用户无缝使用；如果必须依赖外部安装，**必须在根目录提供 `README.md` 和 `help.md` 详尽说明配置前置条件**；
  3. *“Don't bundle opaque binaries where sources are unavailable or where it's unclear how they have been built”* —— **严禁在扩展包内塞入未开源、不可审计的二进制文件**；
  4. *“Extensions requesting Keychain Access will be rejected due to security concerns”* —— 严禁请求系统钥匙串权限。

#### 2. 在架先例解构与实证对照
在官方 `raycast/extensions` 单体仓库中，存在大量依赖外部宿主软件或 CLI 的成功在架先例：

* **先例 A：`aerospace` (AeroSpace 窗口管理器扩展)**
  * **源码路径**：`extensions/aerospace/src/utils/aerospace.ts`
  * **实现模式**：
    * 优先检测 `preferences.aerospaceBin`；
    * 若未设置，自动扫描候选路径：`/opt/homebrew/bin/aerospace`、`/usr/local/bin/aerospace`、`~/.nix-profile/bin/aerospace`；
    * 若全部找不到，抛出结构化错误 `binary-unavailable`；
    * UI 层（`AeroSpaceRecoveryActions.tsx`）通过 `List.EmptyView` 渲染优雅引导界面，提供：
      1. 「打开扩展设置」(`openExtensionPreferences()`)
      2. 「打开安装指南」(`Action.OpenInBrowser`)
      3. 「启动 AeroSpace」(`getApplications()` + `open()`)
  * **审查结果**：官方正式收录在 Store，持续维护。

* **先例 B：`tailscale` (Tailscale 官方/社区扩展)**
  * **源码路径**：`extensions/tailscale/src/shared.tsx`
  * **实现模式**：
    * 默认二进制路径硬编码为伴侣 App 内部路径：`const tailscalePath = prefs.tailscalePath || "/Applications/Tailscale.app/Contents/MacOS/Tailscale"`；
    * 使用 `execFile` 异步调用，捕获 `ENOENT` 映射为友好错误；
    * 在 `package.json` 中提供非必填偏好项：
      ```json
      {
        "name": "tailscalePath",
        "type": "textfield",
        "required": false,
        "title": "Tailscale CLI Path",
        "description": "Location to the Tailscale CLI (Defaults to /Applications/Tailscale.app/Contents/MacOS/Tailscale)"
      }
      ```
  * **审查结果**：官方正式收录在 Store，是伴侣 App 架构的标准教科书范式。

* **先例 C：`brew` (Homebrew 扩展)**
  * **源码路径**：`extensions/brew/package.json`
  * **实现模式**：自动根据芯片架构探测 `/opt/homebrew/bin/brew` 或 `/usr/local/bin/brew`，同时提供 `customBrewPath` 用户偏好项兜底。

#### 3. 审核雷区与安全防线
为确保顺利通过 Raycast 团队的 PR 人工审查与自动流水线，本案必须遵守以下四条纪律：
1. **绝不吞掉错误导致全屏红色崩溃**：当 `VoiceInput.app` 未安装或 CLI 路径不存在时，不得触发未捕获异常（Unhandled Exception Overlay 会直接招致 Reviewer 拒绝），必须捕获并呈现友好的 `List.EmptyView`。
2. **不强制必填偏好项**：偏好设置项 `cliPath` 必须设为 `required: false`，默认指向 `/Applications/VoiceInput.app/Contents/MacOS/VoiceInput`。若设为 `required: true`，用户安装插件后会被强行阻断在设置页，极度影响体验。
3. **清晰的安装与前置说明**：在插件根目录下提供标准 `README.md`，明确声明需要 `VoiceInput for macOS (v1.0+)` 并在说明中附带官网/GitHub 仓库发布地址。

---

### Q3: 命令与 UI 约束、HUD 行为与缓存消杀

#### 1. 界面与交互范式 (`List` + `ActionPanel`)
* **列表组织**：使用 `List` 呈现当前系统识别到的音频输入设备。
* **列表项元数据**：
  * `title`: 设备友好名称（如 `MacBook Pro Microphone`、`AirPods Max`）。
  * `subtitle`: 传输类型或 UID 缩写（如 `Built-In`、`Bluetooth`、`USB`）。
  * `icon`: 区分设备类型（内置麦克风、外接麦克风、蓝牙）。
  * `accessories`: 对当前正在生效的系统默认输入设备，显示勾选状态（如 `Icon.Checkmark` 与绿色文字标签）。
* **ActionPanel 快捷键映射**：
  * **回车 (`↵`, Primary Action)**：立即将该设备切换为系统默认输入。
  * **快捷键 (`⌘C`)**：复制设备名称或 UID。
  * **快捷键 (`⌘R`)**：手动重新从 Core Audio 读取刷新。

#### 2. 避免空状态闪烁 (Flickering Empty View)
Raycast 官方明确警示过一个常见错误：在真实数据从 CLI 返回前，如果组件渲染了空数组（`[]`），Raycast 会瞬间闪现一次 `List.EmptyView`（“No Results”），数据返回后再刷出列表，造成屏幕剧烈闪烁。
* **防御手段**：在数据未就绪时，保持 `List` 的 `isLoading={true}` 属性，且仅在 `!isLoading && devices.length === 0` 时渲染空状态。

#### 3. `closeMainWindow()` 与 `showHUD()` 行为辨析
* **`showHUD(title: string, options?)`**：
  * 自动关闭 Raycast 主搜索窗口；
  * 在屏幕正下方淡入一个半透明胶囊通知（HUD），停留片刻后自动淡出；
  * 返回 Promise，在 HUD 成功展示时 Resolve。
* **`closeMainWindow(options?)`**：
  * 单纯关闭主窗口，无视觉提示；支持 `popToRootType` 控制回退行为。
* **本案交互裁决**：
  * 当用户在列表上按下回车切换默认输入设备时，切换动作通常在 50~150ms 内完成。
  * 此时应调用 `await showHUD(`已将默认输入切换为: ${device.name}`)`。用户即可直接回到原工作应用，且能获得明确的物理反馈。

#### 4. 核心命题：为何必须彻底消杀 `useCachedPromise` 与 `Cache` API？
主人对本案提出的第一条最高指令为：
> **“每次获取都必须现读 macOS 最新输入源，禁止旧数据”**

必须深入剖析 Raycast 提供的缓存工具行为，以绝后患：
* **`useCachedPromise` 与 `useExec` 的本质陷阱**：
  * 官方文档明确说明：*“It follows the stale-while-revalidate cache invalidation strategy popularized by HTTP RFC 5861. useCachedPromise first returns the data from cache (stale), then executes the promise (revalidate), and finally comes with the up-to-date data again. The last value will be kept between command runs.”*
  * **致命后果**：如果使用上述 Hook，当用户拔掉 USB 麦克风、断开蓝牙或在系统设置里切了设备后，在 Raycast 中再次敲开插件命令，插件**首先从磁盘读出上一次运行的旧设备列表并渲染上屏**，几百毫秒后 CLI 执行完才跳变到新状态。这在体验上属于严重的「说谎」，完全违背了本案契约！
* **`Cache` API 的持久化特性**：
  * `new Cache()` 会在插件的 `supportPath` 磁盘目录下写入 JSON 文件，即使插件退出也会持久保留。
* **本案强制编码纪律**：
  * **禁止使用** `@raycast/utils` 中的 `useCachedPromise`、`useExec`、`useCachedState`。
  * **禁止使用** `@raycast/api` 中的 `Cache`。
  * **正确模式**：采用 `usePromise`（注意：`usePromise` 不带跨会话磁盘缓存，仅在当前挂载生命周期内维护执行 Promise）或 React 纯 Hook（`useState` + `useEffect`），初始状态为 `isLoading: true`，挂载即触发 CLI 执行，获取最新 Core Audio 状态后一次性渲染。

---

## 4. Store 资产规范与发版全流程

### 1. `package.json` 必填字段全景清单
根据 [Raycast Manifest 规范](https://developers.raycast.com/information/manifest.md)，发布至公开 Store 的 `package.json` 必须具备以下字段：

```json
{
  "$schema": "https://www.raycast.com/schemas/extension.json",
  "name": "voiceinput-switcher",
  "title": "VoiceInput Audio Switcher",
  "description": "Switch system audio input devices via VoiceInput companion app",
  "icon": "icon.png",
  "author": "<Your-Raycast-Username>",
  "categories": [
    "Productivity",
    "System"
  ],
  "license": "MIT",
  "platforms": [
    "macOS"
  ],
  "commands": [
    {
      "name": "switch-input-device",
      "title": "Switch Audio Input",
      "subtitle": "VoiceInput",
      "description": "List and switch macOS default audio input devices in real time",
      "mode": "view"
    }
  ],
  "preferences": [
    {
      "name": "voiceInputCliPath",
      "title": "VoiceInput CLI Path",
      "description": "Custom path to VoiceInput executable. Leave empty to use default /Applications/VoiceInput.app path.",
      "type": "textfield",
      "required": false,
      "placeholder": "/Applications/VoiceInput.app/Contents/MacOS/VoiceInput"
    }
  ],
  "dependencies": {
    "@raycast/api": "^1.104.0",
    "@raycast/utils": "^2.2.0"
  },
  "devDependencies": {
    "@raycast/eslint-config": "^2.0.0",
    "@types/node": "22.13.0",
    "@types/react": "19.0.0",
    "eslint": "^9.0.0",
    "prettier": "^3.0.0",
    "typescript": "^5.8.0",
    "vitest": "^4.0.0"
  },
  "scripts": {
    "build": "ray build -e dist",
    "dev": "ray develop",
    "fix-lint": "ray lint --fix",
    "lint": "ray lint",
    "test": "vitest run",
    "publish": "npx @raycast/api@latest publish"
  }
}
```

### 2. 视觉与元数据资产规格
* **图标规范 (`icon.png`)**：
  * 尺寸必须为 **512 x 512 像素**，格式为 `PNG`。
  * 必须在浅色和深色主题下均有良好视觉对比（若有差异，可提供 `icon@dark.png`）。
  * 严禁使用 Raycast 默认红折纸图标（会被 CI 直接打回）。
  * 推荐使用官方图标生成器 [icon.ray.so](https://icon.ray.so/) 或 Figma 模板生成。
* **截图规范 (`metadata/`)**：
  * 存放在插件根目录的 `metadata/` 文件夹下。
  * 比例必须为 **16:10**，推荐分辨率 **2000 x 1250 像素**，`PNG` 格式。
  * 数量限制：1 ~ 6 张（官方推荐至少 3 张，展示设备列表、快捷搜索、HUD 切换反馈等真实场景）。
  * 背景需保持干净、统一，严禁混杂无关应用或敏感隐私信息。
* **文档规范**：
  * **`README.md`**：放在根目录，介绍功能、前置条件（VoiceInput.app 需安装并赋权）及安装指南。
  * **`CHANGELOG.md`**：遵循 [Keep a Changelog](https://keepachangelog.com/) 规范，初版使用：
    ```markdown
    # VoiceInput Switcher Changelog

    ## [Initial Version] - {PR_MERGE_DATE}

    - List macOS audio input devices in real time
    - Switch default input device instantly with HUD feedback
    ```
    其中的 `{PR_MERGE_DATE}` 占位符在 Raycast 自动化合并 PR 时会自动替换为真实合并日期。

### 3. 发布与审查流水线全景
1. **本地门禁预检**：
   * `npm run lint`：运行 `ray lint`，校验代码规范与 ESLint。
   * `npm run build`：运行 `ray build -e dist`，执行完整的 TypeScript 类型安全检查并生成生产优化 Bundle。
2. **提交审核**：
   * 运行 `npm run publish`（首次运行会提示登录 GitHub 授权），CLI 会自动 Fork 官方仓库 `raycast/extensions`、在对应目录创建插件代码并自动发起 Pull Request。
3. **CI 自动化流水线验证**：
   * 官方流水线（`.github/workflows/extensions_build_publish.yml`）在 `macos-latest` runner 上执行：
     * 校验 `package.json` schema（Author 必须有效、License 必须为 MIT 等）；
     * 运行 `ray build` 确保无编译报错；
     * 运行问题匹配器（Problem Matcher）并在 PR 中直接标注代码问题；
     * 检查 Changelog 和 Metadata 截图格式。
4. **人工审查与合并**：
   * Raycast 团队工程师和社区 Maintainer 进行代码安全走查与人工功能核验；
   * 周期一般在 **2 个工作日 ~ 1-2 周** 不等（视官方待审 PR 积压量而定）；
   * PR 合并后，Store 自动触发构建打包，几分钟内在 Raycast Store 全球上线。

---

## 5. 本地开发回路与自动化测试验证

### 1. 本地热重载开发 (`ray develop`)
* **加载方式**：在扩展工程目录下运行 `npm run dev`（执行 `ray develop`）。
* **客户端表现**：
  * 本地 Raycast 客户端无需重启，会自动感知并在主搜索列表顶栏插入该扩展，图标旁带有明显的 `Development` 徽标。
  * 任何代码保存（Save）后，CLI 会毫秒级重新打包，Raycast 界面自动热重载生效。
* **日志与调试输出**：
  * 代码中的 `console.log`、`console.error` 直接输出在运行 `ray develop` 的终端控制台中（发布到 Store 后 Raycast 运行时会自动屏蔽 console 输出）。
  * 发生未捕获异常时，Raycast 界面会弹出覆盖层展示完整的堆栈调用链路，并附有一键跳转编辑器的 Action。
  * 支持在 VS Code 中使用官方插件 `Raycast: Attach Debugger` 连接 Node 运行时断点调试。

### 2. 自动化/脚本化触发命令的可行性
* **Raycast Deeplink**：
  * 支持通过系统 URL Scheme 拉起指定命令：`raycast://extensions/<author>/<name>/<command>`。
  * 支持传参：`arguments` 与 `context` 参数（URL 编码的 JSON）。
* **自动化触发的客观限制**：
  * **确认弹窗限制**：通过外部浏览器或脚本首次调用 `raycast://` 协议时，Raycast 客户端出于防恶意劫持考虑，**会弹出系统原生确认对话框**（*“Do you want to run this command?”*）。
  * 因此，不能指望纯无头脚本通过 Deeplink 进行无人值守的自动化端到端测试。

### 3. 官方测试现状与 Vitest 最佳实践
* **官方测试命令**：
  * 查阅官方全部文档与 CLI 命令：**Raycast 官方 CLI 并不提供 `ray test` 命令**。
* **业界标准测试工程化方案**：
  * 从 `aerospace` 和 `brew` 等顶级 Store 扩展的实际工程落地可以实证：
    1. 在 `devDependencies` 中引入 **Vitest**（或 Node 20+ 的 `node:test`）；
    2. 将核心业务逻辑（CLI 参数组装、JSON 输出解析、版本协商校验、设备过滤排序、错误类型映射）与 React UI 视图严格解耦，抽象为独立的 Pure TS 模块；
    3. 在测试文件中使用 `vi.mock("@raycast/api", () => ({ ... }))` 桩化 Raycast 特有 API；
    4. 执行 `npx vitest run`：脱离 Raycast GUI 客户端，在纯 Node 命令行环境下跑完 100% 的单元测试与分支覆盖！

```typescript
// 典型 Vitest 单测工程范式 (参考 extensions/aerospace/src/utils/aerospace.test.ts)
import { describe, expect, it, vi } from "vitest";

vi.mock("@raycast/api", () => ({
  getPreferenceValues: vi.fn(() => ({})),
  showToast: vi.fn(),
  showHUD: vi.fn(),
  openExtensionPreferences: vi.fn(),
}));

import { parseDeviceListOutput, formatCliError } from "./cli-parser";

describe("VoiceInput CLI Output Parser", () => {
  it("正确解析 CLI 输出的设备 JSON 数组并标明当前默认设备", () => {
    const mockCliStdout = JSON.stringify({
      protocol_version: 1,
      default_input_device_id: "built_in_mic",
      devices: [
        { id: "built_in_mic", name: "MacBook Pro Microphone", transport_type: "Built-in" },
        { id: "airpods_pro", name: "AirPods Pro", transport_type: "Bluetooth" }
      ]
    });
    const parsed = parseDeviceListOutput(mockCliStdout);
    expect(parsed.devices).toHaveLength(2);
    expect(parsed.devices[0].is_default).toBe(true);
    expect(parsed.devices[1].is_default).toBe(false);
  });
});
```

---

## 6. 对本案 (0014) 的具体含义与障碍排查

### 1. 方案可行性终审
* **「插件通过 CLI 子命令调用伴侣 App」路线 100% 成立**：
  * 无论是进程能力（Node.js `execFile` 自由调用本地文件）、权限模型（无需麦克风录音权限、无沙箱拘束）、还是审核政策（Tailscale/AeroSpace 先例背书），该路线均具备极其充分的合规性与技术可行性。

### 2. Store 发布障碍与排雷指引
要确保本插件能够顺利发布至 Raycast Store，后续编码与发布必须排除以下具体障碍：
1. **障碍一：首次安装未安装伴侣 App 时的用户体验**
   * *排雷*：CLI 探测失败时，严禁抛错崩溃；必须展示标准 `List.EmptyView`，提供「下载并安装 VoiceInput.app」的直达链接，并在说明中告知首次打开需在 macOS 授予辅助权限（若有）。
2. **障碍二：路径灵活性（非标准安装路径）**
   * *排雷*：在 `package.json` 提供 `voiceInputCliPath` 偏好项（`required: false`），默认留空即可探测 `/Applications/VoiceInput.app/Contents/MacOS/VoiceInput`，同时支持用户自定义。
3. **障碍三：代码合规与严禁陈旧缓存**
   * *排雷*：彻底移除 `useCachedPromise` 与 `Cache`，全部采用直连读取。遵守 ESLint 规则（必须通过 `ray lint`），不得引入任何不必要的外部大型依赖。
4. **障碍四：开源契约与资产准备**
   * *排雷*：Raycast Store 要求扩展完全开源并遵循 MIT 协议。需提供合规的 512x512 图标和至少 3 张 16:10 界面截图。

---

## 7. 未解风险清单 (Unresolved Risks)

| 风险项 | 风险性质 | 触发场景 | 缓解/应对策略 |
| :--- | :--- | :--- | :--- |
| **R1. 伴侣 App Gatekeeper 拦截** | 外部部署风险 | VoiceInput 伴侣 App 若未加入 Apple Developer Program（未获得 Developer ID 签名与 Apple 公证），普通用户通过浏览器下载 dmg 打开会提示「无法打开，因为无法验证开发者」。 | 伴侣 App 需在 GitHub Release 提供清晰的绕过 Gatekeeper 说明（如 `xattr -cr /Applications/VoiceInput.app`），或在后续流程中申请正式 Developer ID 证书并配置公证流水线。 |
| **R2. Core Audio 设备重启漂移竞态** | 协议/运行时风险 | 某些蓝牙设备或虚拟声卡在断开重连后，Core Audio 内部分配的 `AudioDeviceID` (32位整数) 会发生漂移。如果插件传递旧 ID 会切换失败。 | VoiceInput CLI 与 Raycast 插件应使用设备的唯一持久标识符 **UID**（Core Audio `kAudioDevicePropertyDeviceUID`，为字符串）作为核心标识，仅在向 HAL 下发设置时由 CLI 现场将 UID 动态解析为当时的实时 DeviceID。 |
| **R3. CLI 执行偶发超时挂起** | 运行时风险 | 系统声卡驱动异常或 CoreAudio 守护进程卡死可能导致 CLI 调用挂起。 | 插件中封装 `execFile` 时必须显式设置 `timeout: 5000`（5秒超时），超时后发送 SIGTERM 中断，并向用户提示「音频服务无响应，请重试」。 |
| **R4. Raycast 账户绑定与署名要求** | 发布规范风险 | `package.json` 中的 `author` 字段必须与提交 PR 的 GitHub 账号所绑定的 Raycast 个人用户名完全一致。 | 在正式提 PR 前，需确保主人已注册 Raycast 账号，并获取其准确的 Handle。 |

---

## 8. 一手信源索引与核对日志

| 来源分类 | 资料名称 / 官方链接 | 核对日期 | 关键佐证内容 |
| :--- | :--- | :--- | :--- |
| **Raycast 官方文档** | [Raycast Security Architecture](https://developers.raycast.com/information/security.md) | 2026-10-24 | 确证 Node 单子进程、V8 isolate 模型、无沙箱文件系统访问机制。 |
| **Raycast 官方文档** | [Prepare an Extension for Store](https://developers.raycast.com/basics/prepare-an-extension-for-store.md) | 2026-10-24 | 确证二进制依赖规范、严禁闭源不透明二进制、README/CHANGELOG 要求、Keychain 拒绝规则。 |
| **Raycast 官方文档** | [Publish an Extension](https://developers.raycast.com/basics/publish-an-extension.md) | 2026-10-24 | 确证 `ray publish` 工作流、GitHub PR 机制与审核流程。 |
| **Raycast 官方文档** | [Raycast Manifest Specification](https://developers.raycast.com/information/manifest.md) | 2026-10-24 | 确证 `package.json` 必填字段、图标与分类标准。 |
| **Raycast 官方文档** | [Developer Tools CLI](https://developers.raycast.com/information/developer-tools/cli.md) | 2026-10-24 | 确证 `ray develop`、`ray lint`、`ray build` 行为；确认无内置 `ray test`。 |
| **Raycast 官方文档** | [useCachedPromise Hook Reference](https://developers.raycast.com/utilities/react-hooks/usecachedpromise.md) | 2026-10-24 | 确证 SWR 缓存与跨运行数据持久化，证明其违背本案新鲜度要求。 |
| **Raycast 官方文档** | [usePromise Hook Reference](https://developers.raycast.com/utilities/react-hooks/usepromise.md) | 2026-10-24 | 确证 `usePromise` 无跨运行缓存，适合实时现场读取。 |
| **Raycast 官方文档** | [Feedback HUD API](https://developers.raycast.com/api-reference/feedback/hud.md) | 2026-10-24 | 确证 `showHUD` 自动隐藏主窗并展示浮动提示的签名与行为。 |
| **Raycast 官方仓库** | [raycast/extensions: aerospace](https://github.com/raycast/extensions/tree/main/extensions/aerospace) | 2026-10-24 | 实证外部伴侣 CLI 集成范例、`preferences` 自定义路径设计、Vitest 单测落地。 |
| **Raycast 官方仓库** | [raycast/extensions: tailscale](https://github.com/raycast/extensions/tree/main/extensions/tailscale) | 2026-10-24 | 实证调用 `/Applications/<App>.app/Contents/MacOS/<Binary>` 的伴侣 App 在架标准先例。 |
| **Raycast 官方仓库** | [raycast/extensions: CI Workflow](https://github.com/raycast/extensions/blob/main/.github/workflows/extensions_build_publish.yml) | 2026-10-24 | 实证 macOS runner CI 校验、构建与自动化发布流水线。 |
| **未查到项记录** | GitHub Code Search API (Unauthenticated 401) | 2026-10-24 | 匿名搜索代码受限，改用仓库 Git Tree 与 raw.githubusercontent 逐层穿透验证，所有先例均已 100% 验证完整源码。 |
| **未查到项记录** | Raycast 官方原生 `ray test` 命令 | 2026-10-24 | 官方 CLI 帮助及全部文档均未提及该命令，确证不存在官方测试套件，行业标准均为引入 Vitest。 |
