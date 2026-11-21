# Changelog

## 0.3.0 — 2026-11-22（M3，已完成）

- 新增 `ReplyObservation`、`ReplyProfile` / `NormalizedRect`、`LumaGrid`；`ReplyCompletionDetector` 增加 `phaseChangedAt`、observation 入口、settling 重开；`unknown` 保留 generating 历史。
- 新增每目标 `ReplySignalAnalyzer`：160×160 灰度帧差、SHA-256 文本指纹、Vision 本地 OCR；OCR 按“首帧/失败恢复/画面变化 + `ocrInterval`”节流，不保留正文。
- 新增 `AXStopControlProbe`：绑定进程、唯一标题窗口、enabled Stop-like `AXButton`，最多 600 节点/深度 8；无权限返回 nil，视觉继续。
- Dashboard 接入检测管线：0.25s 取帧、最多 0.5s 检测一次；暂停/移除/关窗清理检测状态；回写前复核 generation/live/未暂停。
- 卡片 footer 显示 `State <relative>` 与 `Frame <relative>`；hint 改为 “M3: frame diff + OCR · Accessibility optional”。
- 新增 `Fixtures/` 合成聊天 fixture、`scripts/build-m3-fixtures.sh` 与只读 `PhaseSampler`。
- 合成 fixture 验收：A/B/C 正例 finish→Completed 上界 2.072/1.865/2.220s；`stallAx` 4.002s 内始终 Streaming；`static`/`blink` 全程 Idle，无 Completed。
- 新增 `ReplyProfileRegistry` 与豆包工作视觉 Profile：replyROI 排除侧栏/输入框，真实会话正例 Settling→Completed 1.07s，完成后 30s+ Completed；静态 11.9s 全程 Idle。
- 空闲资源约 11.7% CPU / 123MB；早期每 0.5s 无条件 OCR 的 37.5% CPU 已修。
- 新增 20 个用例（合计 59 tests / 0 failures），新增 ADR-014。
- M3 已按 owner 口径完成：合成 fixture + 豆包工作真实视觉链路；AX 增强与 ChatGPT/Claude/Cursor 标定延后 M4。

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
