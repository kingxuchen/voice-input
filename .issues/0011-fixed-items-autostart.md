---
id: "0011"
title: "底部固定项：声音设置入口 / 登录自启 / 退出"
labels: [ready-for-agent]
status: open
claimed-by: ""
blocked-by: ["0008", "0010"]
---

## Parent

[0006 VoiceInput v1 实现规格](0006-voiceinput-v1-spec.md)

## What to build

菜单底部三个固定项齐活："打开声音设置…"直达系统设置声音页；"登录时启动"toggle 用 `SMAppService.mainApp` 实现注册/注销与真实状态回显（权限被系统关到 `.requiresApproval` 时引导打开登录项设置页）；"退出 VoiceInput" 正常终止进程。自启必须在 0010 产出的已安装 `.app` 上验证（SMAppService 硬要求：正规 bundle id + 固定路径）。

## Acceptance criteria

- [ ] "打开声音设置…"直达系统设置声音输入页
- [ ] 开启"登录时启动"后 App 出现在系统设置登录项列表；关闭后移除；toggle 状态回显真实 SMAppService 状态
- [ ] 系统关闭自启权限（`.requiresApproval`）时，操作 toggle 能引导打开登录项设置页
- [ ] "退出 VoiceInput"正常终止，无僵尸进程
- [ ] 以上各项在已安装 `.app`（非 `swift run`）上实测通过
- [ ] 状态映射等纯逻辑有测试覆盖；SMAppService 真注册走手动验收
