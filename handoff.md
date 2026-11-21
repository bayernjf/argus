# handoff — Argus

- 更新日期：2026-11-21
- 当前阶段：M0 仓库骨架 + 产品文档
- Tier：2

## 当前状态

- 仓库骨架：Swift Package，`ArgusCore` library + `Argus` executable + `ArgusCoreTests`。
- UI：SwiftUI Dashboard 骨架，三张 mock 监控卡片，展示缩略图区、目标名、回复状态和最近帧时间。
- 核心逻辑：`ReplyPhase` / `ReplyActivity` / `ReplyCompletionDetector`；`settling` 窗口避免单帧误判，缺信号时走 `unknown`。
- 文档：PRD、技术架构、里程碑、功能点、ADR、测试策略、发布策略、风险清单已落盘。
- 验证：`swift build` 通过；`swift test` 7 tests / 0 failures。

## 未接线

- ScreenCaptureKit 真实窗口枚举与捕获。
- 屏幕录制权限引导与失败恢复。
- OCR / Accessibility / 帧差信号提取。
- 点击缩略图激活目标窗口。
- 目标列表本地持久化、暂停/移除、资源上限。
- 签名、公证、`.app` 打包与内测分发。

## 下一步

1. M1：单窗口捕获 + 权限引导 + 一张真实卡片。
2. M2：多目标捕获、缩略图刷新、点击切换到目标窗口。
3. M3：回复完成检测 v1，建立 fixture 与人工标注集。
4. M4：性能、隐私、异常路径与 4 小时稳定性验收。

## 待拍板

- 首版支持哪些 macOS AI 客户端。
- 单次最多同时监控多少个目标。
- 完成检测的误报/漏报阈值与可接受延迟。
- 多窗口/多实例时卡片如何绑定目标窗口。
- 是否走 Mac App Store；当前默认 Developer ID + 公证。
- `one-code` 可复用模块边界与许可证。
- 产品正式英文名/中文名是否保持 Argus。

## 证据

```text
swift build -> Build complete!
swift test  -> Executed 7 tests, with 0 failures
```

真实捕获、权限、切换窗口的验收不得用 mock 代替；需要在目标 macOS 版本上手工记录。
