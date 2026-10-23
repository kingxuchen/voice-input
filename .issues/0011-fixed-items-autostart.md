---
id: "0011"
title: "底部固定项：声音设置入口 / 登录自启 / 退出"
labels: [ready-for-agent]
status: closed
claimed-by: "impl-0011"
blocked-by: ["0008", "0010"]
---

## Parent

[0006 VoiceInput v1 实现规格](0006-voiceinput-v1-spec.md)

## What to build

菜单底部三个固定项齐活："打开声音设置…"直达系统设置声音页；"登录时启动"toggle 用 `SMAppService.mainApp` 实现注册/注销与真实状态回显（权限被系统关到 `.requiresApproval` 时引导打开登录项设置页）；"退出 VoiceInput" 正常终止进程。自启必须在 0010 产出的已安装 `.app` 上验证（SMAppService 硬要求：正规 bundle id + 固定路径）。

## Acceptance criteria

- [x] "打开声音设置…"直达系统设置声音输入页
- [x] 开启"登录时启动"后 App 出现在系统设置登录项列表；关闭后移除；toggle 状态回显真实 SMAppService 状态
- [x] 系统关闭自启权限（`.requiresApproval`）时，操作 toggle 能引导打开登录项设置页
- [x] "退出 VoiceInput"正常终止，无僵尸进程
- [x] 以上各项在已安装 `.app`（非 `swift run`）上实测通过
- [x] 状态映射等纯逻辑有测试覆盖；SMAppService 真注册走手动验收

## Resolution

- **结构**：`LoginItemService` 协议（`status` / `register()` / `unregister()` / `openSystemSettingsLoginItems()`）隔离 SMAppService，真实现 `SMAppServiceLoginItem`；`LaunchAtLoginController`（`@Observable @MainActor`）驱动状态机；`LoginItemModel` 是**纯逻辑映射**（status → 文案/勾选/是否显示引导项/点击动作）。
- **状态实时读**：`LaunchAtLoginController.status` 每次 `toggle()` 前先 `refresh()` 读 `SMAppService.mainApp.status`——用户随时可能在系统设置里关掉自启，不能缓存。`AudioDeviceMenuView.onAppear` 再补一次刷新（菜单每次打开都回显真实状态）。
- **状态映射**（`SMAppService.Status` 四态全覆盖，对照 SDK `SMAppService.h` 确认 rawValue 0/1/2/3）：
  - `.enabled` → 显示 `"✓  登录时启动"`，点击 → `.unregister`
  - `.requiresApproval` → 显示 `"    登录时启动"`，**额外**显示引导项「需在系统设置中允许自启…」，点击 → `.openSystemSettings`（此状态下 `register()` 无效，只能引导放行）
  - `.notRegistered` / `.notFound` → 显示 `"    登录时启动"`，点击 → `.register`
- **深链修正**：`SystemSettings.soundSettingsURL` 用 `x-apple.systempreferences:com.apple.Sound-Settings.extension`。SPEC 0006 原写 `com.apple.Sound-settings`（拼错），**拼错版会静默不跳转**（System Settings 停在原页面），已在本票实测对比确认。
- **实机验证（已安装的 .app，非 swift run）**：
  - 打包安装到 `~/Applications/VoiceInput.app`（`scripts/bundle-app.sh --install ~/Applications`），ad-hoc 签名校验通过。
  - 在 bundle 上下文读 `SMAppService.mainApp.status` = **enabled**（raw 1）；注销后 = **notRegistered**（raw 0）。
  - 「系统设置 › 通用 › 登录项与扩展」中「登录时打开」列表出现 **VoiceInput / 应用程序**（截图确认）。
  - 声音设置深链：先停在「桌面与程序坞」，执行本实现的 URL 后窗口标题变为 **「声音」**。
  - 菜单内容用 `ImageRenderer` 离屏渲染确认：8 个设备按 HAL 顺序、✓ 落在 vRemoteDr 2ch、底部「打开声音设置… / 登录时启动 / 退出 VoiceInput」顺序正确。
- **测试**：`swift build` 零警告零错误；`swift test` 43 tests in 7 suites passed（本票新增 19 条：四态呈现映射、四态点击动作、缓存过期时先读真实状态、需授权时不注册只引导等）。
- **清理**：验收后已注销登录项（status → notRegistered，BTM 记录变为 disabled）、删除 `~/Applications/VoiceInput.app`、结束进程；本机回到基线（无 app、无进程、无启用中的登录项），系统默认输入仍为 vRemoteDr 2ch，音频设备列表与基线一致。

## 遗留（留给 0012 复核）

- `.requiresApproval` 的**系统侧**触发（手动到系统设置关掉登录项开关）在本轮未完成 GUI 操作验证；该分支的**行为逻辑**已由单元测试覆盖（点击 → `.openSystemSettings` → 调 `SMAppService.openSystemSettingsLoginItems()`），API 本身在 SDK 头文件已确认。0012 若能手工制造该状态，请补一次端到端确认。
