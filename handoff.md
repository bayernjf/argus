# handoff — Argus

- 更新日期：2026-11-21
- 当前阶段：M1 已完成并通过实机验收（2026-11-21）；下一步 M2
- Tier：2

## 当前状态

- 仓库骨架：Swift Package，`ArgusCore` library + `Argus` executable + `ArgusCoreTests`；Package.swift 已升到 swift-tools 6.0（Swift 6 语言模式，与 AGENTS.md 对齐）。
- UI：SwiftUI Dashboard 接入 `DashboardStore`（@MainActor @Observable，docs/02 预定模块）；「Add target」打开 `WindowPickerSheet`；卡片显示真实窗口信息与内存缩略图（scaledToFit 整窗可见）。
- M1a `.app` bundle：`scripts/make-app.sh` 组装 `build/Argus.app`（bundle id `com.bayernjf.argus`，Info.plist 含 `NSScreenCaptureUsageDescription`；优先使用本机自签 `Argus Dev` 身份，缺失时回退 ad-hoc，`ARGUS_SIGN_IDENTITY` 可覆盖）。
- M1b 窗口枚举与权限：`WindowEnumerator`（SCShareableContent → `CaptureWindowInfo` 过滤）+ `PermissionManager`（CGPreflight/CGRequest，激活时热更新）；被拒时 picker 内提供「Open System Settings」+「Retry」，不崩溃。
- M1c 真实帧捕获：`ScreenCaptureSession`（`SCContentFilter(desktopIndependentWindow:)`、2 fps、960 宽比例输出、queueDepth 3、仅内存保留最新帧）；`DashboardStore` 管会话生命周期并以 250ms 轮询把帧喂给卡片；卡片显示 LIVE · 2 FPS / CONNECTING / CAPTURE ERROR 状态；窗口关闭通过 `CGWindowList` 复核转为失败态，权限撤销以失败态呈现，不崩溃。
- 核心逻辑：`ReplyPhase` / `ReplyActivity` / `ReplyCompletionDetector`；新增 `CaptureWindowInfo` 过滤与 `TargetApplication` 映射（纯逻辑，6 个单测覆盖）。
- 文档：docs/07 bundle id 已确认（`com.bayernjf.argus`）；docs/03 M1 已标记完成；docs/08 R-10 已闭环。

## 实机验收结果（2026-11-21，owner 本机 macOS 27）

- 通过：启动/空态；denied 降级引导（Open System Settings + Retry，不崩溃）；窗口枚举（真实列表、过滤自身窗口、空标题处理）；首帧 ~1s（≤2s）；三目标并发 LIVE；帧轮询秒级刷新；内容变化 ≤1s 缩略图更新（2fps + 250ms 轮询）；关闭目标窗口 → CAPTURE ERROR 不崩溃；卡片右键 Remove；授权链路（系统设置 → 重启生效）。
- 平台发现（已记录 docs/08）：① `CGRequestScreenCaptureAccess` 在 macOS 27 不弹系统授权框，正确路径是引导到系统设置；② 屏幕录制授权须重启应用生效；③ `desktopIndependentWindow` 关闭后 SCStream 不回调 `didStopWithError`，持续投递冻结帧（已用 CGWindowList 复核修复）；④ TCC 条目的 csreq 在创建时冻结，改签名后须重置条目重建。
- 签名根治：ad-hoc 每次重建换 CDHash 导致授权反复失效；已建立本机自签 `Argus Dev` 证书并让 `make-app.sh` 自动优先使用，TCC 按证书记忆授权，重建不再掉权限。
- 遗留未实测：最小化目标窗口的卡片表现（docs/06 矩阵项，M4 soak 覆盖）；`swift run Argus` 对照实验（本机宿主已持屏幕录制授权，对照失去区分度，改在干净环境验证）；ChatGPT 专项捕获（M1 退出条件是任意真实窗口，已用豆包/ZCode/终端达成；客户端矩阵属 M3 拍板项）。

## 未接线

- OCR / Accessibility / 帧差信号提取（M3）。
- 点击缩略图激活目标窗口（M2，将引入辅助功能权限）。
- 目标列表本地持久化、暂停/恢复、资源上限（M2；已加最小的卡片右键 Remove）。
- 会话自动重建（窗口关闭后需手动重新添加，M2）。
- 最小化窗口的 SCStream 行为（docs/02 开放问题，M4 soak 记录）。
- 签名、公证、DMG/ZIP 与内测分发（M5；bundle 已就绪，签名身份方案已定）。

## 下一步

1. M2：`CaptureCoordinator` 多目标协调、点击切换（辅助功能权限）、目标列表持久化。
2. M2 开工前拍板：首版客户端矩阵、单次目标上限、多窗口绑定规则。

## 待拍板

- 首版支持哪些 macOS AI 客户端（M1 验收已覆盖任意窗口；客户端矩阵影响 M3 Profile 设计）。
- 单次最多同时监控多少个目标。
- 完成检测的误报/漏报阈值与可接受延迟（M3 fixture 实测后定）。
- 多窗口/多实例时卡片如何绑定目标窗口。
- 是否走 Mac App Store；当前默认 Developer ID + 公证。
- `one-code` 可复用模块边界与许可证。
- 产品正式英文名/中文名是否保持 Argus。

## 证据

```text
swift build -> Build complete!
swift test  -> Executed 13 tests, with 0 failures（新增 6 个 CaptureWindowInfo 单测）
./scripts/make-app.sh -> build/Argus.app (com.bayernjf.argus, Authority=Argus Dev)
实机验收 -> 上述 2026-11-21 结果（截图取证 /tmp/argus-*.png，验收会话留存）
```

> 2026-11-21 事故记录：验收自动化期间误关了一个正在运行 `codebuddy` 的 Terminal 窗口（终止其 node 进程）；已向 owner 说明，重启 codebuddy 即可恢复。教训：窗口自动化只操作自建窗口。
