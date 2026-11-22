# Argus

macOS 本地多目标 AI 回复监控台。

Argus 把多个目标软件窗口收进一个 Dashboard：每个目标软件一张监控卡片，卡片展示实时缩略图和 AI 回复状态；点击缩略图切换到对应目标软件窗口。首版只做 macOS，本地优先，不上传屏幕内容。

- 产品名：Argus（内部定名，2026-11-21）
- Tier：Tier 2（一般项目）
- 当前阶段：M4 内部 Alpha 已完成（2026-11-22）。3 目标 active OCR 4h 平均 5.92%，豆包真实视觉链路与隐私检查通过；FR-11 的 D03/D04 已实机、D01/D07 由单测覆盖；M5 签名/公证/分发按“只自用”暂缓
- 仓库：https://github.com/bayernjf/argus

## 当前状态

- `ArgusCore` 已建立回复状态模型、`ReplyCompletionDetector` 状态机、窗口过滤、目标持久化与恢复逻辑。
- M1 已实机验收：`.app` bundle、屏幕录制权限引导、真实窗口枚举、单窗口 2 fps 捕获、内存缩略图、窗口关闭失败态。
- M2 已实机验收：目标持久化与严格不猜恢复、3 目标上限、点击缩略图 AX 精确切窗、暂停/恢复冻结最后一帧、窗口关闭 10 秒重建、600/900 深浅色；3 目标 30 分钟 soak 全程 LIVE。
- M3 已完成：视觉帧差 + Vision OCR 文本哈希 + 可选 AX Stop 控件；每目标 `ReplyProfile` 参数；豆包工作视觉 Profile 已接入；Dashboard 显示 `Streaming / Settling / Completed / Unknown` 与最近状态时间。
- M3 合成 fixture 正/负验收通过：正例完成上界 1.865–2.220s；`stallAx` 4s 内保持 Streaming；`static`/`blink` 不误报 Completed。豆包工作真实视觉链路通过：Settling→Completed 1.07s，静态 11.9s Idle；AX 增强与 ChatGPT/Claude/Cursor 标定延后 M4。
- M4 4h soak 通过：448 px / 1 fps、3 目标 active OCR，480 samples / 239.8 分钟；CPU avg 5.92%（median 5.90%、p95 6.80%、max 7.30%），RSS avg 102.3 MB（91.6–122.9 MB）；PID 全程一个，48/48 次相位采样 3/3 Streaming，无 NO_WINDOW。
- FR-11 最小诊断页已接入：FPS、检测耗时、状态转换、D01–D08 错误码、脱敏复制。实机验证 D03_UNKNOWN 与 D04_ACTIVATION；D01/D07 由 `DiagnosticsStoreTests` 覆盖。复制文本不含窗口标题或 OCR 正文。
- `Completed` 本地通知已接入：目标进入 `Completed` 时发 macOS 系统通知；标题/正文只含目标应用名，不含窗口标题或 OCR 正文；通知权限被拒不影响 Dashboard。本机系统日志已确认通知请求 `hasError: 0`、`alertStyle: banner` 并进入通知历史（`build/notify-runtime-20261122.log`）。
- App 图标已接入：`Resources/AppIcon.icns` 通过 `CFBundleIconFile` 打进 `build/Argus.app`；Dock 实测显示正常。品牌符号与备选方向存于 `Resources/Brand/`。
- `swift build` 通过；`swift test` 76 tests / 0 failures（56 ArgusCoreTests + 20 ArgusTests）。

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
│   ├── ArgusCore/          # 纯模型、捕获/激活协议、匹配与恢复逻辑、回复状态机
│   └── Argus/              # SwiftUI、ScreenCaptureKit、Accessibility、权限与文件存储
├── Tests/ArgusCoreTests/   # 状态机、窗口过滤、持久化与恢复回归测试
├── Resources/              # AppIcon.icns 与品牌资产
├── scripts/make-app.sh     # 组装并签名 build/Argus.app
├── scripts/soak.sh         # 3 目标 soak 的 CPU/RSS 采样（手工加目标）
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

当前证据（M0–M4）：

```text
swift build  -> Build complete
swift test   -> ArgusCoreTests 56 + ArgusTests 20 = 76 tests, 0 failures
./scripts/build-m3-fixtures.sh -> build/fixtures/Apps/A-D + PhaseSampler
./scripts/make-app.sh -> build/Argus.app (com.bayernjf.argus, Authority=Argus Dev)
M3 正例 -> finish→Completed 上界 A 2.072s / B 1.865s / C 2.220s
M3 负例 -> stallAx 4.002s 内始终 Streaming；static/blink 全程 Idle
M3 豆包工作 -> Settling→Completed 1.07s；静态 11.9s 全程 Idle
M4 4h soak -> 480 samples / 239.8 min；PID 84290 稳定；CPU avg 5.92%（p95 6.80、max 7.30）；
              RSS avg 102.3 MB（91.6–122.9）；48/48 相位 3/3 Streaming；无 NO_WINDOW
M4 诊断 -> D03_UNKNOWN / D04_ACTIVATION 实机可见；D01/D07 单测覆盖；Copy 文本无窗口标题/OCR
```

M1–M4 已实机验收；M4 证据见 [handoff.md](handoff.md)，CPU/4h 日志在 `build/soak-20261122-161107.log`、`build/soak-cputime-20261122-final3.log`。M4 的验收口径是“合成 fixture + 豆包工作真实视觉链路”；D01/D07 未做破坏性实机诱发，由单测覆盖。ChatGPT/Claude/Cursor 标定与 AX 增强仍按计划后移。涉及权限、目标窗口和人工观察的结论必须另附记录，不用 mock 测试代替。
