# Changelog

## 0.2.0 — 2026-11-21（M2a/M2b/M2c，已实机验收）

- 目标列表持久化到 `~/Library/Application Support/Argus/targets.json`：版本化、原子写、损坏文件隔离。
- 重启恢复严格不猜：同 bundle 只有唯一可用窗口才自动绑定，多候选显示 `NEEDS WINDOW` 并可重选。
- 硬上限 3 个目标：超限时 Add 置灰，picker 内提示。
- 修复 `CaptureFrame.targetID` 与卡片 id 不一致。
- 窗口存在性检查改为每轮询一次共享快照，减少 `CGWindowList` 调用。
- 新增 17 个单测（合计 32 tests / 0 failures），其中 4 个覆盖 targets.json 的读写与损坏隔离。
- M2b：点击缩略图切窗；AX 标题匹配（单窗口回退、重复标题不猜）；先匹配后激活，失败不切错窗口。
- Accessibility 权限由状态栏按钮显式申请；未授权时只激活应用并提示降级。
- 新增 7 个匹配规则单测（合计 39 tests / 0 failures）。
- M2c：捕获态新增 `PAUSED` / `WINDOW CLOSED`；暂停停流并保留最后一帧，恢复重新开流。
- 窗口关闭后每 10 秒按严格唯一规则自动重建；多候选/零候选继续等待，不猜窗口。
- 启动、恢复、暂停、移除之间增加竞态守卫，不挂载过期 SCStream。
- 最小窗口宽度 900→600，状态条用 `ViewThatFits` 在窄窗隐藏提示；新增 `scripts/soak.sh`。
- 实机验收修复：目标 App 退出时窗口消失优先于 `SCStream` 失败，落到可恢复的 `WINDOW CLOSED`。
- 实机验收修复：同一 bundle 多实例时跨进程收集 AX 窗口再匹配，避免激活到未绑定的实例。
- 实机验收修复：soak 脚本 CPU/RSS 拆为独立 CSV 字段。
- M2 实机验收：3 目标 30 分钟 soak 全程 LIVE；点击切窗 10/10 为 97–115 ms；600/900 深浅色无横向溢出。

## 0.1.0 — 2026-11-21

- 建立 Argus Swift Package 骨架：`ArgusCore`、SwiftUI app、单元测试。
- 落盘 PRD、技术架构、里程碑、功能点、ADR、测试与发布文档。
- 实现 `ReplyCompletionDetector` 的 `idle / streaming / settling / completed / unknown` 状态机。
