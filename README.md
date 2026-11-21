# Argus

macOS 本地多目标 AI 回复监控台。

Argus 把多个目标软件窗口收进一个 Dashboard：每个目标软件一张监控卡片，卡片展示实时缩略图和 AI 回复状态；点击缩略图切换到对应目标软件窗口。首版只做 macOS，本地优先，不上传屏幕内容。

- 产品名：Argus（内部定名，2026-11-21）
- Tier：Tier 2（一般项目）
- 当前阶段：M2 进行中（M1 已实机验收；M2a 持久化完成、待实机验收）
- 仓库：https://github.com/bayernjf/argus

## 当前状态

- `ArgusCore` 已建立回复状态模型、`ReplyCompletionDetector` 状态机、窗口过滤、目标持久化与恢复逻辑。
- M1 已实机验收：`.app` bundle、屏幕录制权限引导、真实窗口枚举、单窗口 2 fps 捕获、内存缩略图、窗口关闭失败态。
- M2a 已落码待验收：目标列表持久化（版本化、原子写、损坏隔离）、重启严格不猜恢复、3 目标上限、`NEEDS WINDOW` 重选路径。
- `swift build` 通过；`swift test` 32 tests / 0 failures。
- 点击切窗（M2b）、暂停/恢复与自动重建（M2c）、OCR/辅助功能信号（M3）尚未接线。

## 文档

| 文档 | 用途 |
|---|---|
| [docs/00-文档索引与治理.md](docs/00-文档索引与治理.md) | 文档地图、状态口径与更新规则 |
| [docs/01-PRD-产品需求规格.md](docs/01-PRD-产品需求规格.md) | 产品目标、范围、功能需求与验收口径 |
| [docs/02-技术架构设计.md](docs/02-技术架构设计.md) | 捕获、检测、切换、权限与隐私架构 |
| [docs/03-里程碑与迭代计划.md](docs/03-里程碑与迭代计划.md) | M0–M5 的范围与退出条件 |
| [docs/04-功能点清单.md](docs/04-功能点清单.md) | FR 编号、优先级、里程碑与状态 |
| [docs/05-技术选型与决策记录.md](docs/05-技术选型与决策记录.md) | 已接受的架构决策与替代方案 |
| [docs/06-测试与验收策略.md](docs/06-测试与验收策略.md) | 单元、集成、手工矩阵与门禁 |
| [docs/07-发布与分发.md](docs/07-发布与分发.md) | 内测、签名、公证与分发边界 |
| [docs/08-风险与开放问题.md](docs/08-风险与开放问题.md) | 误判、权限、性能与待拍板项 |
| [docs/09-立项与能力迁移.md](docs/09-立项与能力迁移.md) | 立项背景、能力迁移与启动条件 |
| [handoff.md](handoff.md) | 当前交接状态与下一步 |

## 快速开始

```bash
swift build
swift test
swift run Argus
```

要求 macOS 14+ 与 Xcode Command Line Tools。

## 结构

```text
argus/
├── Package.swift
├── Sources/
│   ├── ArgusCore/          # 纯模型、捕获协议、持久化与恢复逻辑、回复状态机
│   └── Argus/              # SwiftUI、ScreenCaptureKit、权限与文件存储
├── Tests/ArgusCoreTests/   # 状态机、窗口过滤、持久化与恢复回归测试
├── scripts/make-app.sh     # 组装并签名 build/Argus.app
└── docs/                   # PRD、架构、里程碑、功能点、ADR、测试与发布
```

## 边界

- 不替代目标软件，不注入提示词，不做通用窗口管理器。
- 不把屏幕内容上传云端；MVP 不接任何网络服务。
- 不持久化截图；缩略图与帧只在内存中存活。
- 检测不到可靠信号时显示 `Unknown`，不伪造“已完成”。
- Windows 平台不在首版范围，后续迁移时单独立项。
- MVP 不单独建 `argus-landing`；公共入口后续挂到 BayJF 的 `/products/argus`。

## 验证

当前证据（M0–M2a）：

```text
swift build  -> Build complete
swift test   -> ArgusCoreTests 28 + ArgusTests 4 = 32 tests, 0 failures
./scripts/make-app.sh -> build/Argus.app (com.bayernjf.argus, Authority=Argus Dev)
```

M1 已实机验收；M2a 的实机验收清单见 [handoff.md](handoff.md)，通过前不标 verified。涉及权限、目标窗口和人工观察的结论必须另附记录，不用 mock 测试代替。
