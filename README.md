# Argus

macOS 本地多目标 AI 回复监控台。

Argus 把多个目标软件窗口收进一个 Dashboard：每个目标软件一张监控卡片，卡片展示实时缩略图和 AI 回复状态；点击缩略图切换到对应目标软件窗口。首版只做 macOS，本地优先，不上传屏幕内容。

- 产品名：Argus（内部定名，2026-11-21）
- Tier：Tier 2（一般项目）
- 当前阶段：M1 代码完成（单窗口捕获 + 权限流程），待实机验收
- 仓库：https://github.com/bayernjf/argus

## 当前状态

- `ArgusCore` 已建立回复状态模型、`ReplyCompletionDetector` 状态机与窗口过滤逻辑。
- M1a/M1b/M1c 已落地：`.app` bundle、窗口枚举与权限流程、单窗口 ScreenCaptureKit 捕获。
- 卡片显示真实窗口信息与 2 FPS 内存缩略图；窗口关闭会转为失败态。
- `swift build` 通过；`swift test` 13 个测试通过。
- OCR/辅助功能信号与点击切窗尚未接线，分别属于 M3 与 M2。

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
│   ├── ArgusCore/          # 纯模型、捕获协议、回复状态机
│   └── Argus/              # SwiftUI app 骨架与 mock Dashboard
├── Tests/ArgusCoreTests/   # 状态机回归测试
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

当前 M0 证据：

```text
swift build  -> Build complete
swift test   -> Executed 7 tests, 0 failures
```

涉及真实捕获的验收必须另附屏幕录制权限、目标窗口和人工观察记录，不用 mock 测试代替。
