# AGENTS.md — Argus

本仓库是 Argus：macOS 本地多目标 AI 回复监控台，Tier 2。

## 产品边界

- 只观察用户明确选择的目标窗口；不做全屏录制。
- 不替代目标软件，不注入提示词，不做通用窗口管理器。
- MVP 不联网、不上传屏幕内容、不持久化截图。
- 首版只支持 macOS；Windows 迁移不在当前范围。
- 检测不到可靠信号时输出 `unknown`，不得伪造 `completed`。

## 技术约定

- Swift 6 / SwiftUI，最低 macOS 14。
- `ArgusCore` 只放模型、协议与纯逻辑，不 import SwiftUI / AppKit。
- `Sources/Argus` 负责 SwiftUI、ScreenCaptureKit、Vision、Accessibility 等 OS 集成。
- 捕获帧只保存在内存；日志不得包含窗口正文、提示词或截图。
- 新增网络、遥测、持久化或第三方 API 前，先写 ADR 并取得 owner 同意。

## 命令

```bash
swift build
swift test
swift run Argus
```

提交前至少运行 `swift build && swift test`。涉及真实捕获的改动另附手工验证记录。

## Git

- 本地工作分支：`dev`；`main` 通过 PR 合入，不直接提交。
- 提交信息用英文 Conventional Commits，subject ≤ 50 字符，正文说明目的。
- 每个提交只处理一个独立目的；不添加 AI co-author。
- 不提交 `.build/`、DerivedData、真实截图、用户窗口内容或凭证。

## 文档

- 产品范围以 `docs/01-PRD-产品需求规格.md` 为准。
- 功能编号以 `docs/04-功能点清单.md` 为准。
- 架构决策写入 `docs/05-技术选型与决策记录.md`，不要只在聊天里拍板。
- 每次阶段推进更新 `handoff.md`；完成项必须能对上代码、测试或手工证据。
