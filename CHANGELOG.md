# Changelog

## 0.2.0 — 2026-11-21（M2a/M2b，待实机验收）

- 目标列表持久化到 `~/Library/Application Support/Argus/targets.json`：版本化、原子写、损坏文件隔离。
- 重启恢复严格不猜：同 bundle 只有唯一可用窗口才自动绑定，多候选显示 `NEEDS WINDOW` 并可重选。
- 硬上限 3 个目标：超限时 Add 置灰，picker 内提示。
- 修复 `CaptureFrame.targetID` 与卡片 id 不一致。
- 窗口存在性检查改为每轮询一次共享快照，减少 `CGWindowList` 调用。
- 新增 17 个单测（合计 32 tests / 0 failures），其中 4 个覆盖 targets.json 的读写与损坏隔离。
- M2b：点击缩略图切窗；AX 标题匹配（单窗口回退、重复标题不猜）；先匹配后激活，失败不切错窗口。
- Accessibility 权限由状态栏按钮显式申请；未授权时只激活应用并提示降级。
- 新增 7 个匹配规则单测（合计 39 tests / 0 failures）。

## 0.1.0 — 2026-11-21

- 建立 Argus Swift Package 骨架：`ArgusCore`、SwiftUI app、单元测试。
- 落盘 PRD、技术架构、里程碑、功能点、ADR、测试与发布文档。
- 实现 `ReplyCompletionDetector` 的 `idle / streaming / settling / completed / unknown` 状态机。
