---
id: 0005
title: "实现蓝图定稿（SPEC.md）"
labels: [wayfinder:grilling]
status: closed
claimed-by: "mainline-session"
blocked-by: []
---

## Question

汇总 0002（API 方案）、0003（打包方案）、0004（行为规格）的结论为一份可照做的 `SPEC.md`：项目结构、文件清单、关键 API 用法与代码骨架、打包脚本、验收清单。与主人确认后关闭——至此地图走完，路线清晰，进入编码执行（地图之外，由后续 session 照 SPEC 实施）。

## Resolution

- 汇总 0002（Core Audio 方案）/ 0003（SwiftPM 打包）/ 0004（行为规格）为实现规格，发布为 [0006-voiceinput-v1-spec.md](0006-voiceinput-v1-spec.md)（labels 含 ready-for-agent，编码 session 直接认领照做）。地图 Destination 所指的"SPEC.md"交付物即该规格票。
- 唯一测试接缝 `AudioDeviceProviding`（协议隔离 Core Audio，真实现 CoreAudioDeviceProvider）已向主人展示，随"按地图规格和 spec 进行任务票据开发"指令确认。
- 后续任务拆解由 to-tickets 接手（开发票 0007+），不再属于本图。
