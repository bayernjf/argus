# handoff — Argus

- 更新日期：2026-11-21
- 当前阶段：M2 进行中（M2a/M2b 已落码，待实机验收）；M1 已完成并通过实机验收
- Tier：2

## 当前状态

- 仓库骨架：Swift Package，`ArgusCore` library + `Argus` executable + `ArgusCoreTests`；Package.swift 已升到 swift-tools 6.0（Swift 6 语言模式，与 AGENTS.md 对齐）。
- UI：SwiftUI Dashboard 接入 `DashboardStore`（@MainActor @Observable，docs/02 预定模块）；「Add target」打开 `WindowPickerSheet`；卡片显示真实窗口信息与内存缩略图（scaledToFit 整窗可见）。
- M1a `.app` bundle：`scripts/make-app.sh` 组装 `build/Argus.app`（bundle id `com.bayernjf.argus`，Info.plist 含 `NSScreenCaptureUsageDescription`；优先使用本机自签 `Argus Dev` 身份，缺失时回退 ad-hoc，`ARGUS_SIGN_IDENTITY` 可覆盖）。
- M1b 窗口枚举与权限：`WindowEnumerator`（SCShareableContent → `CaptureWindowInfo` 过滤）+ `PermissionManager`（CGPreflight/CGRequest，激活时热更新）；被拒时 picker 内提供「Open System Settings」+「Retry」，不崩溃。
- M1c 真实帧捕获：`ScreenCaptureSession`（`SCContentFilter(desktopIndependentWindow:)`、2 fps、960 宽比例输出、queueDepth 3、仅内存保留最新帧）；`DashboardStore` 管会话生命周期并以 250ms 轮询把帧喂给卡片；卡片显示 LIVE · 2 FPS / CONNECTING / CAPTURE ERROR 状态；窗口关闭通过 `CGWindowList` 复核转为失败态，权限撤销以失败态呈现，不崩溃。
- Picker 去重：已监控窗口在列表中排除、`addTarget` 防重复兜底、移除后下次枚举恢复；全部合格窗口被监控时空列表给独立提示。
- M2a 目标持久化与重启恢复：`PersistedTarget` / `TargetFile`（版本 1，未知版本拒读）+ `TargetFileStore`（`~/Library/Application Support/Argus/targets.json`，原子写，损坏文件隔离为 `targets.corrupt-*.json`）+ `TargetRestorer`（严格不猜）。
- M2a 上限与状态：硬上限 3（`TargetLimits`），超限时 Add 置灰、picker 内提示；恢复失败的目标显示 `NEEDS WINDOW`，卡片内「Re-select window」/右键菜单可重新绑定，不新增第 4 张卡。
- M2a 顺手修：`CaptureFrame.targetID` 之前是会话内随机 UUID，与卡片无关；现在由 `DashboardStore` 传入卡片 id。窗口存在性检查从「每目标每轮询一次 CGWindowList」改为「每轮询一次共享快照」。
- M2b 点击切换：`AccessibilityWindowActivator` + `WindowMatchPolicy`；点击缩略图按 bundle 找进程、读 AX 窗口标题、先匹配后激活。唯一匹配或单窗口才 raise；多候选/无候选不激活应用，避免跳错窗口；AX 未授权时只激活应用，顶部 banner 提示授权。Accessibility 请求由状态栏「Enable exact switching」显式触发，不在点击卡片时弹系统框。
- 核心逻辑：`ReplyPhase` / `ReplyActivity` / `ReplyCompletionDetector`；`CaptureWindowInfo` 过滤与映射、目标恢复纯逻辑均有单测覆盖。
- 文档：docs/03 M2 标记进行中；docs/04 状态更新；docs/06 证据刷新到 M2a；docs/07 bundle id 已确认；docs/08 R-10 已闭环。

## 实机验收结果（M1，2026-11-21，owner 本机 macOS 27）

- 通过：启动/空态；denied 降级引导（Open System Settings + Retry，不崩溃）；窗口枚举（真实列表、过滤自身窗口、空标题处理）；首帧 ~1s（≤2s）；三目标并发 LIVE；帧轮询秒级刷新；内容变化 ≤1s 缩略图更新（2fps + 250ms 轮询）；关闭目标窗口 → CAPTURE ERROR 不崩溃；卡片右键 Remove；授权链路（系统设置 → 重启生效）。
- 平台发现（已记录 docs/08）：① `CGRequestScreenCaptureAccess` 在 macOS 27 不弹系统授权框，正确路径是引导到系统设置；② 屏幕录制授权须重启应用生效；③ `desktopIndependentWindow` 关闭后 SCStream 不回调 `didStopWithError`，持续投递冻结帧（已用 CGWindowList 复核修复）；④ TCC 条目的 csreq 在创建时冻结，改签名后须重置条目重建。
- 签名根治：ad-hoc 每次重建换 CDHash 导致授权反复失效；已建立本机自签 `Argus Dev` 证书并让 `make-app.sh` 自动优先使用，TCC 按证书记忆授权，重建不再掉权限。
- 遗留未实测：最小化目标窗口的卡片表现（docs/06 矩阵项，M4 soak 覆盖）；`swift run Argus` 对照实验（本机宿主已持屏幕录制授权，对照失去区分度，改在干净环境验证）；ChatGPT 专项捕获（M1 退出条件是任意真实窗口，已用豆包/ZCode/终端达成；客户端矩阵属 M3 拍板项）。

## M2a 待实机验收（代码与单测已完成）

- 添加 3 个目标后 Add 置灰；picker 显示上限提示，不再允许第 4 个。
- 退出 App 再启动：3 张卡片按原顺序恢复并重新 LIVE。
- 关掉某个目标窗口后重启：该卡片显示 `NEEDS WINDOW`，点「Re-select window」可换窗口，卡片 id 不变。
- 同一 bundle 开多窗口后重启：该目标不自动绑定，显示 `NEEDS WINDOW`（严格不猜）。
- 无屏幕录制权限启动：卡片以 `NEEDS WINDOW` 呈现权限原因；授权后 Retry 可恢复捕获。
- 损坏 `targets.json`：启动不崩溃，文件被隔离为 `targets.corrupt-*.json`。

## M2b 待实机验收（代码与匹配规则单测已完成）

- 未授予 Accessibility：点 LIVE 卡片 → 应用前置，banner 说明只切到应用；不崩溃。
- 点「Enable exact switching」→ 系统授权提示/设置页；授权后按钮消失，点卡片不再出现降级 banner。若系统设置已勾选但按钮仍在，重启 Argus（AX 生效时点待实测）。
- 已授权：点卡片 → 目标窗口置顶；同应用的其他窗口不被误提。
- 同应用两窗口、标题不同：点 A 只提 A。
- 同应用两窗口、标题相同：banner 报 ambiguous，当前前台应用不被切走。
- 目标应用已退出：banner 提示 not running，不切到别的应用。
- 目标窗口最小化：点卡片可恢复并前置；多 Space 行为记录实测结果，不宣称已支持。

## 未接线

- OCR / Accessibility 控件信号 / 帧差提取（M3；AX 目前只用于窗口切换，不参与检测）。
- 暂停/恢复、会话自动重建与退避（M2c；当前窗口关闭后需手选或重选）。
- 最小化窗口的 SCStream 行为（docs/02 开放问题，M4 soak 记录）。
- 签名、公证、DMG/ZIP 与内测分发（M5；bundle 已就绪，签名身份方案已定）。

## 下一步

1. 先做 M2b 实机验收（上方清单），把结果补进本文件。
2. M2c：暂停/恢复、会话自动重建、3 目标 30 分钟 soak、900/600px 布局检查。
3. M2 收口后更新 docs/06 手工矩阵与 handoff 证据，再进 M3。

## 已拍板（2026-11-21）

- 单次最多监控 3 个目标；M4 soak 有数据后再评估放宽。
- 重启恢复严格不猜：同 bundle 只有唯一可用窗口才自动绑定，多候选一律 `NEEDS WINDOW` 交回用户。
- 首版客户端矩阵推到 M3 再定；M2 验收只要求任意真实窗口。
- 激活先匹配再激活；多候选或无候选不激活应用；AX 缺失只做应用级切换并明示降级（ADR-012）。

## 待拍板

- 完成检测的误报/漏报阈值与可接受延迟（M3 fixture 实测后定）。
- 多显示器 / Space 下激活优先级与行为（M2c/M4 实测，不猜）。
- 是否走 Mac App Store；当前默认 Developer ID + 公证。
- `one-code` 可复用模块边界与许可证。
- 产品正式英文名/中文名是否保持 Argus。

## 证据

```text
swift build -> Build complete!
swift test  -> 39 tests, 0 failures（ArgusCoreTests 35 + ArgusTests 4）
               （M2a 17：7 TargetRestorer + 5 PersistedTarget/上限 + 1 卡片身份 + 4 TargetFileStore；
                 M2b 7：WindowMatchPolicy）
./scripts/make-app.sh -> build/Argus.app (com.bayernjf.argus, Authority=Argus Dev, 2026-11-21 22:15)
M1 实机验收 -> 上述 2026-11-21 结果（截图取证 /tmp/argus-*.png，验收会话留存）
M2a 实机验收 -> 未执行；上方「M2a 待实机验收」为验收清单
M2b 实机验收 -> 未执行；上方「M2b 待实机验收」为验收清单；AX 真实 raise 不能用 mock 代替
```

> 2026-11-21 事故记录：验收自动化期间误关了一个正在运行 `codebuddy` 的 Terminal 窗口（终止其 node 进程）；已向 owner 说明，重启 codebuddy 即可恢复。教训：窗口自动化只操作自建窗口。
