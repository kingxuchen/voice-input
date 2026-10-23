---
id: "0012"
title: "验收收尾：手动清单全绿，关规格票"
labels: [ready-for-agent]
status: open
claimed-by: ""
blocked-by: ["0009", "0011"]
---

## Parent

[0006 VoiceInput v1 实现规格](0006-voiceinput-v1-spec.md)

## What to build

v1 收官验收：逐条跑完 SPEC「Testing Decisions」里的 8 条手动验收清单（构建测试全绿、打包可跑、列表与系统一致、切换与勾选闭环、热插拔回落、同名序号、自启 toggle、常驻半小时资源观察），修复发现的尾差，最终关闭规格票 0006 并回填验收记录。

## Acceptance criteria

- [ ] SPEC 8 条手动验收清单逐条通过，每条在票内留一行结果记录
- [ ] 常驻半小时内存/CPU 无异常增长（活动监视器观察）
- [ ] `swift build && swift test` 全绿
- [ ] 尾差已修复，或为超范围问题开新票记录（不塞进 v1）
- [ ] 关闭规格票 0006，Resolution 回填验收结论
