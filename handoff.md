# handoff — Argus

- 更新日期：2026-11-22
- 当前阶段：M4「内部 Alpha」已完成（2026-11-22）。448 px / 1 fps 的 3 目标 active OCR 4h 平均 5.92%；豆包真实 OCR、隐私检查、D03/D04 诊断实机通过，D01/D07 由单测覆盖。M3 已完成并合入 `main`，merge `0b33a53`；M4 已通过 PR #12 合入 `main`，merge `195d986`；通知随 PR #14 合入 `main`，merge `33d37e8`，并完成本机系统通知投递验证；M5 按“只自用”暂缓。
- Tier：2

## 当前状态

- 仓库骨架：Swift Package，`ArgusCore` library + `Argus` executable + `ArgusCoreTests`；Package.swift 已升到 swift-tools 6.0（Swift 6 语言模式，与 AGENTS.md 对齐）。
- UI：SwiftUI Dashboard 接入 `DashboardStore`（@MainActor @Observable，docs/02 预定模块）；「Add target」打开 `WindowPickerSheet`；卡片显示真实窗口信息与内存缩略图（scaledToFit 整窗可见）。
- M1a `.app` bundle：`scripts/make-app.sh` 组装 `build/Argus.app`（bundle id `com.bayernjf.argus`，Info.plist 含 `NSScreenCaptureUsageDescription`；优先使用本机自签 `Argus Dev` 身份，缺失时回退 ad-hoc，`ARGUS_SIGN_IDENTITY` 可覆盖）。
- M1b 窗口枚举与权限：`WindowEnumerator`（SCShareableContent → `CaptureWindowInfo` 过滤）+ `PermissionManager`（CGPreflight/CGRequest，激活时热更新）；被拒时 picker 内提供「Open System Settings」+「Retry」，不崩溃。
- M1c 真实帧捕获：`ScreenCaptureSession`（`SCContentFilter(desktopIndependentWindow:)`、2 fps、960 宽比例输出、queueDepth 3、仅内存保留最新帧）；`DashboardStore` 管会话生命周期并以 250ms 轮询把帧喂给卡片；卡片显示 LIVE · 2 FPS / CONNECTING / CAPTURE ERROR 状态；窗口关闭通过 `CGWindowList` 复核转为 `WINDOW CLOSED`（M2c 起可自动重建），权限撤销以失败态呈现，不崩溃。
- Picker 去重：已监控窗口在列表中排除、`addTarget` 防重复兜底、移除后下次枚举恢复；全部合格窗口被监控时空列表给独立提示。
- M2a 目标持久化与重启恢复：`PersistedTarget` / `TargetFile`（版本 1，未知版本拒读）+ `TargetFileStore`（`~/Library/Application Support/Argus/targets.json`，原子写，损坏文件隔离为 `targets.corrupt-*.json`）+ `TargetRestorer`（严格不猜）。
- M2a 上限与状态：硬上限 3（`TargetLimits`），超限时 Add 置灰、picker 内提示；恢复失败的目标显示 `NEEDS WINDOW`，卡片内「Re-select window」/右键菜单可重新绑定，不新增第 4 张卡。
- M2a 顺手修：`CaptureFrame.targetID` 之前是会话内随机 UUID，与卡片无关；现在由 `DashboardStore` 传入卡片 id。窗口存在性检查从「每目标每轮询一次 CGWindowList」改为「每轮询一次共享快照」。
- M2b 点击切换：`AccessibilityWindowActivator` + `WindowMatchPolicy`；点击缩略图按 bundle 收集所有同名实例的 AX 窗口并读取标题、先匹配后激活。唯一匹配或单窗口才 raise；多候选/无候选不激活应用，避免跳错窗口；AX 未授权时只激活应用，顶部 banner 提示授权。Accessibility 请求由状态栏「Enable exact switching」显式触发，不在点击卡片时弹系统框。
- M2c 生命周期：`CaptureState` 增加 `paused` / `windowClosed`；暂停停流并保留最后一帧（卡片标注 PAUSED），恢复优先绑定原窗口、失效才走严格唯一匹配；窗口关闭后每 10 秒枚举一次，仅在同 bundle 唯一可用窗口时自动重绑，多候选继续等待；暂停、移除、重绑与启动中的竞态均有守卫，不挂载过期 SCStream。布局最小宽度 900→600，状态条用 `ViewThatFits` 在窄窗隐藏提示；新增 `scripts/soak.sh` 采样 CPU/RSS 供 3 目标 30 分钟 soak 使用。
- 核心逻辑：`ReplyPhase` / `ReplyActivity` / `ReplyCompletionDetector`；`CaptureWindowInfo` 过滤与映射、目标恢复纯逻辑均有单测覆盖。
- M3 核心：新增 `ReplyObservation`、`ReplyProfile` / `NormalizedRect`、`LumaGrid`；`ReplyCompletionDetector` 增加 `phaseChangedAt`、observation 重载、settling 重开；`unknown` 清 settle 但保留 generating 历史。`ReplyProfile.generic`：settle 1.0s、OCR 0.5s、changeThreshold 0.005、confidence 0.6、`controlROI=nil`，避免正文 “stop” 被当控件。
- M3 信号：每目标一个 `ReplySignalAnalyzer` actor；160×160 灰度帧差、SHA-256 文本指纹（不保留正文）、Vision `.fast` 本地 OCR、OCR 按“首帧/失败恢复/画面变化 + 间隔”节流；`AXStopControlProbe` 仅查绑定进程、唯一标题、enabled Stop-like `AXButton`，最多 600 节点/深度 8，`nil`=不可测量。
- M3 融合：AX/视觉 Stop 为 true 直接 generating；文本变化 0.95；OCR 不可用降 0.45 走 unknown；文本稳定 + 小视觉变化置信 0.7，防止 spinner/光标期误完成；纯稳定 0.9。
- M3 Dashboard：每目标 `replyProfiles`/`detectors`/`analyzers`/`lastDetectionAt`；0.25s 取帧、检测最多 0.5s 一次；回写前复核 generation/live/未暂停；暂停、移除、关窗清理检测状态；卡片 footer 两行 `State <relative>` / `Frame <relative>`；hint 改为 “M4: frame diff + OCR · diagnostics local-only”。
- M4 诊断（已实机验证）：新增 `DiagnosticReport` / `DiagnosticsStore` / `DiagnosticsView`；记录每目标 FPS、检测耗时、最近状态转换与 D01–D08 错误码；`Copy diagnostics` 只复制脱敏文本，不含截图、OCR 正文或窗口标题。2026-11-22 实机验证 `D03_UNKNOWN`（关闭 fixture A）与 `D04_ACTIVATION`（点击已关闭目标的切窗按钮）；D01/D07 由 `DiagnosticsStoreTests` 覆盖。`swift test` 76 tests / 0 failures。
- 本地通知：新增 `Sources/Argus/Notifications/ReplyNotifier.swift`，在 `DashboardStore.setPhase` 进入 `Completed` 时发 macOS 本地通知；正文只含目标应用名，不含窗口标题或 OCR 正文。`ReplyNotifierTests` 2 项覆盖文案脱敏与空名称回退。2026-11-22 实机 fixture A `Streaming→Completed` 后，系统日志出现 `Adding notification request` 与 `Added notification request: [ hasError: 0 ]`，NotificationCenter 记录 `alertStyle: banner` 并加入历史；因截图/录屏使 `displayShared`，banner 被系统静音，证据 `build/notify-runtime-20261122.log`。
- App 图标：用户选定方向 B（字母 A 与眼睛负形）。1024 母版 `Resources/AppIcon-1024.png` 生成 `Resources/AppIcon.icns`，`scripts/make-app.sh` 通过 `CFBundleIconFile=AppIcon` 打进 bundle；Dock 实测图标正常。方向 A「全视之眼」与方向 C「三窗监控」保留在 `Resources/Brand/`，分别供品牌符号/加载动画与游戏/IP 插画使用。
- M4 最终 4h soak：16:11:07–20:11:25，Argus PID `84290` 全程不变；480 samples / 239.8 分钟，CPU avg 5.92%、median 5.90%、P95 6.80%、max 7.30%；RSS avg 102.3 MB（91.6–122.9 MB）；48/48 相位采样 3/3 Streaming，0 NO_WINDOW。日志 `build/soak-20261122-161107.log`、`build/soak-cputime-20261122-final3.log`、`build/soak-phase-20261122-final3.log`。
- M3 fixture：`Fixtures/ArgusChatProbe.swift` + `Fixtures/PhaseSampler.swift` + `scripts/build-m3-fixtures.sh`；A/B/C 三个合成 bundle，场景 `normal/stall/stallAx/static/blink`；事件日志只记生命周期标签与时间戳。
- 文档：docs/02 检测章节为 M3 实际实现；docs/03 M3 标为完成；docs/04 FR-04 verified、FR-12 仍 in_progress（本地 Profile 文件与损坏回退留 M4）；docs/05 ADR-014；docs/06 证据刷新到 M3；docs/08 R-01/R-02/R-13/R-14 更新。

## 实机验收结果（M1，2026-11-21，owner 本机 macOS 27）

- 通过：启动/空态；denied 降级引导（Open System Settings + Retry，不崩溃）；窗口枚举（真实列表、过滤自身窗口、空标题处理）；首帧 ~1s（≤2s）；三目标并发 LIVE；帧轮询秒级刷新；内容变化 ≤1s 缩略图更新（2fps + 250ms 轮询）；关闭目标窗口 → CAPTURE ERROR 不崩溃；卡片右键 Remove；授权链路（系统设置 → 重启生效）。
- 平台发现（已记录 docs/08）：① `CGRequestScreenCaptureAccess` 在 macOS 27 不弹系统授权框，正确路径是引导到系统设置；② 屏幕录制授权须重启应用生效；③ `desktopIndependentWindow` 关闭后 SCStream 不回调 `didStopWithError`，持续投递冻结帧（已用 CGWindowList 复核修复）；④ TCC 条目的 csreq 在创建时冻结，改签名后须重置条目重建。
- 签名根治：ad-hoc 每次重建换 CDHash 导致授权反复失效；已建立本机自签 `Argus Dev` 证书并让 `make-app.sh` 自动优先使用，TCC 按证书记忆授权，重建不再掉权限。
- 遗留未实测：最小化目标窗口的卡片表现（docs/06 矩阵项，M4 soak 覆盖）；`swift run Argus` 对照实验（本机宿主已持屏幕录制授权，对照失去区分度，改在干净环境验证）；ChatGPT 专项捕获（M1 退出条件是任意真实窗口，已用豆包/ZCode/终端达成；客户端矩阵属 M3 拍板项）。

## M2 实机验收结果（2026-11-21，自建 probe，未捕获用户内容）

结论：M2 四条退出条件全部通过，M2a/M2b/M2c 标完成。

目标与恢复：

- 3 个自建 probe 同时 `LIVE · 2 FPS`，状态条 `3/3`，Add 置灰并提示上限 3；三张缩略图分别显示 A/B/C 内容。
- 三窗口都在时重启 Argus：三卡按原顺序恢复 `LIVE`。
- 关闭某一目标后重启：该卡显示 `NEEDS WINDOW`；重新选窗后恢复 `LIVE`。
- 同一 bundle 两个窗口时重启：C 显示 `NEEDS WINDOW`，文案“2 windows … Re-select the one you want”，不自动猜。
- 关闭目标窗口：卡片进入 `WINDOW CLOSED`，提示等待；10 秒级重试内重开同一唯一窗口自动恢复 `LIVE`。
- 同 bundle 两个窗口时关闭旧窗口：保持 `WINDOW CLOSED` 等待，不自动绑定任一候选；右键 Re-select 可手动绑定。
- 损坏 `targets.json` 的隔离由 `TargetFileStoreTests` 覆盖（39 tests / 0 failures）。

暂停与生命周期：

- A 暂停 → `PAUSED`，最后一帧保留，12 秒后帧时间不再增长；恢复 → `LIVE`，PAUSED 计数归零。
- `CONNECTING` 阶段暂停未稳定复现（AX 按钮在状态切换后重建，批量点击只命中第一次）；窗口最小化、多 Space 激活未实测。三项均不在 M2 四条退出条件内，留作 M4 回归/实测项。

点击切换：

- AX 未授权：点 A 缩略图只激活应用并显示降级 banner；授予 Argus 辅助功能权限并重启后按钮消失。
- 已授权：点 A 卡片精确前置 `Argus Probe A`。
- 同一应用两个窗口、标题相同且目标已绑定：banner 显示“2 windows of Argus Probe C match. Close the duplicates or re-select the card.”，不 raise 任一 C 窗口。
- 同一应用两个窗口、标题不同：绑定 `Argus Probe C Window` 后点卡片，`AXFocusedWindow` 为 `Argus Probe C Window`，第二窗口未被 raise。
- 点击时延：distinct-title 双窗口下连续 10 次，点击到 C 应用 active 为 97–115 ms，10/10 在 1.5 秒内，且焦点窗口均为绑定的 C1。

布局：

- 600px 深色/浅色：状态条四项指标完整、右侧提示隐藏、卡片单列、无横向溢出。
- 900px 深色/浅色：双列、右侧提示显示、无横向溢出；浅色下文字与状态色可读。

30 分钟 soak：

- 3 目标全程 `LIVE`；0/10/20/30 分钟截图均为 A/B/C 各自内容，无串流/错绑。
- 61 个样本（30 秒间隔）：CPU 平均 12.3%（6.8–22.2%），RSS 平均 120 MB（110–148 MB）。
- 日志：`build/soak-20261121-235849.log`。

验收中发现并修复（均已 push `origin/dev`）：

- `42a5b88`：目标 App 退出时 `SCStream` 可能先 `didStopWithError`；`pollFrames` 先查 `CGWindowList` 窗口消失，保证落到可恢复的 `WINDOW CLOSED`，而不是 `CAPTURE ERROR`。
- `a120aab`：同一 bundle 有两个存活实例时，激活只检查第一个进程，可能 raise 目标未绑定的窗口；改为收集所有实例的 AX 窗口，再走同一套唯一标题策略。
- `a1c460f`：`scripts/soak.sh` 的 awk 把 CPU 与 RSS 拼成一列；改为两字段独立输出，soak CSV 可用。

证据：

- 布局：`build/argus-m2-600.png`、`build/argus-m2-900.png`、`build/argus-m2-600-light.png`、`build/argus-m2-900-light.png`。
- 最终三目标：`build/argus-m2-final.png`。
- soak：`build/soak-20261121-235849.log`。
- probe 与测试 `targets.json` 验收后删除，不进入仓库。

## M3 合成 fixture 验收结果（2026-11-22，自建 fixture，未捕获用户内容）

结论：检测机制的正/负两轮通过；这是合成聊天窗口，不是真实 ChatGPT/Claude/Cursor。后续豆包工作真实视觉链路通过，owner 于 2026-11-22 接受该组合作为 M3 退出证据；AX 增强与其余客户端标定延后 M4。

正例：

- A/B/C 均 `Idle → Streaming → Settling → Completed`。
- fixture `finish` 到首次 `Completed` 的上界：A 2.072s、B 1.865s、C 2.220s，均在 PRD §9 草案 ≤3s 内。
- 日志：`/tmp/m3-positive-phases.log`、`/tmp/m3-p-A.log`、`/tmp/m3-p-B.log`、`/tmp/m3-p-C.log`。

负例（OCR 节流后复测）：

- A `static` 全程 `Idle`，从未 `Completed`；C `blink` 全程 `Idle`，从未 `Completed`。
- B `stallAx`：spinner 停、文本冻结、只有 enabled AX Stop 按钮；4.002s stall 内始终 `Streaming`，无 `Settling`/`Completed`；stall 结束后 `Settling`（1294.280）→ `Completed`（1295.330）。
- 更早一轮 `stall`（spinner 继续转）也保持 Streaming，但无法单独隔离 AX；`stallAx` 专门证明 AX 增强信号阻止高置信误判。
- 日志：`/tmp/m3-negative-phases.log`（180 样本；1280.380 3×Idle → 1286.390 B Streaming → 1294.280 B Settling → 1295.330 B Completed；A/C 从未 Completed）。
- 相位采样：0.1s；日志只含 phase 与 fixture 生命周期标签，不含正文。

UI 与布局：

- `/tmp/argus-m3-streaming-ui.png`：3/3 LIVE，A/B/C 均 `Streaming`，footer “State 2 sec Frame 0 sec”。
- `/tmp/argus-m3-completed-ui.png`：A/C `Completed`，B 仍 `Settling`（截图瞬间），中间态可见。
- `build/argus-m3-600.png` / `build/argus-m3-900.png`：深色 600×700 单列、900×700 双列，状态行不溢出。
- `build/argus-m3-600-light.png` / `build/argus-m3-900-light.png`：浅色同尺寸复测通过；已恢复深色与 1411×923 窗口。

资源：

- 早期每 0.5s 无条件 OCR：3 个静态目标约 37.5% CPU。
- 改为画面变化才 OCR + AX 1s 缓存后，空闲 `top` 约 11.7% CPU / 123MB，接近 M2 soak 的 12.3% 基线。
- M3 活跃 OCR 期间未做完整 soak；PRD §9 的 ≤8% 属 M4 目标。

踩到/已修：

- macOS 27 SDK 的 `Vision.NormalizedRect` 与 `ArgusCore.NormalizedRect` 重名，App 层显式写 `ArgusCore.NormalizedRect`。
- `CaptureFrame` 的 `CGImage` 不可变但非 Sendable，标记 `@unchecked Sendable` 以跨 actor。
- `swift test` 默认只跑 `ArgusCoreTests`；`ArgusTests` 需 `swift test --filter ArgusTests`。
- AX 遍历在 detached task 中返回后重新校验 capture generation/live/暂停，避免重绑窗口时把旧进程信号写进新 generation 的缓存。
- 验收后已停止 3 个 fixture 与 Argus 测试进程；`targets.json` 移到 `/tmp/argus-m3-targets-final.json`，`/tmp/ArgusM3Fixtures` 已删除；证据日志与截图保留。

owner 验收结论（2026-11-22）：

- 接受“3 个合成 fixture bundle + 豆包工作真实视觉链路”作为 M3 退出证据。
- AX 增强、生成中长停顿真实负例、ChatGPT/Claude/Cursor 标定延后 M4；M3 不再等这三项。


## M3 豆包工作真实客户端视觉链路验收（2026-11-22，合成会话）

结论：豆包工作的视觉/OCR 链路通过正例与静态负例；AX 增强路径不可用，因此本次只算第一证据源验收，不算 AX 验收。

客户端与边界：

- `/Applications/DoubaoWork.app`，bundle `com.work.pc.doubao`，Chromium 内核。
- 使用“文件 → 新建对话”（⌘N）创建独立会话，chat id `38455735961348354`；只使用合成提示词，已有会话内容未用于本次结论或落盘。
- AX 限制：窗口级 AX 树只暴露窗口/边框控件，不暴露 Web 内容里的 Stop；`AXStopControlProbe` 不适合作为该客户端主信号。

Profile：

- `ReplyProfileRegistry.doubaoWork`：replyROI x=0.17 y=0.08 w=0.80 h=0.78；controlROI x=0.88 y=0.90 w=0.07 h=0.07；settle 1.0s；OCR 0.5s；changeThreshold 0.005；minConfidence 0.6。
- 未加 ROI 的全窗基线出现 `Completed → Streaming → Settling` 循环；加 ROI 后空白/静态会话稳定 `Idle`。

正例：

- 发送时间 1795286002.31；`Idle` 1795286002.32 → `Streaming` 1795286007.73 → `Settling` 1795286008.75 → `Completed` 1795286009.82。
- Settling→Completed 1.07s；按最后可见变化近似 ≤1.1s，低于 PRD §9 草案 ≤3s。
- 完成后 30s+ 保持 `Completed`，未重新进入 Streaming。
- 日志 `/tmp/argus-doubao-positive-roi.log`；Dashboard `/tmp/argus-doubao-completed.png`。

静态负例：

- Argus 重启后同一已完成会话从 `Idle` 开始；1795286077.14–1795286089.06 共 11.9s 全 `Idle`，无 Streaming/Settling/Completed。
- 日志 `/tmp/argus-doubao-static-idle.log`；Dashboard `/tmp/argus-doubao-static-idle.png`。

测试与构建：

- `swift build` 通过；`swift test` 48 个 `ArgusCoreTests` 0 failures；`swift test --filter ArgusTests` 11 个 0 failures；合计 59。
- 新增 `Sources/Argus/ReplyProfileRegistry.swift` 与 `Tests/ArgusTests/ReplyProfileRegistryTests.swift`；`DashboardView` 默认注入 registry。

未覆盖（延后 M4）：

- 生成中长停顿/思考停顿的真实负例；豆包工作 AX 增强；ChatGPT/Claude/Cursor；3 个真实客户端矩阵。

## M3 交付状态（2026-11-22）

- M3 代码/Profile/验收记录：`941cc69`（检测管线与 Dashboard）、`f342fdf`（合成 fixture 与构建脚本）、`1bfed2d`（M3 文档）、`335edbc`（豆包工作 Profile）、`dcb201b`（豆包工作视觉验收）、`a227092`（M3 状态收口）。
- `dev` 已推送至 `baf46f0`；PR #11 已合并到 `main`，merge `0b33a53`。
- PR #9：`https://github.com/bayernjf/argus/pull/9`，CI `build-and-test` 通过（两次检查均 SUCCESS）；merge `57dd732`。
- PR #10：`https://github.com/bayernjf/argus/pull/10`；merge `6a6f43c`。
- PR #11：`https://github.com/bayernjf/argus/pull/11`；merge `0b33a53`。
- PR #12：`https://github.com/bayernjf/argus/pull/12`；merge `195d986`，CI `build-and-test` 通过。
- PR #14：`https://github.com/bayernjf/argus/pull/14`；merge `33d37e8`，CI `build-and-test` 通过（`2bd55fb` 修默认参数 SILGen 崩溃，`ef8f83b` 用 `@preconcurrency import UserNotifications` 修 Swift 6.1 Sendable 错误）。
- 清理：fixture 进程与 Argus 测试进程已停止；测试 `targets.json` 归档到 `/tmp/argus-m3-targets-final.json`；`/tmp/ArgusM3Fixtures` 已删除；证据日志与截图保留；豆包工作合成会话与误发消息已由用户手动删除。

## M4 内部 Alpha（已完成，2026-11-22）

结论：CPU、4h soak、豆包真实 OCR、隐私检查通过；诊断 D03/D04 实机、D01/D07 单测覆盖。M4 验收完成，可进入 M5。

最终 4h soak：

- 2026-11-22 16:11:07–20:11:25，共 480 个 30 秒样本，覆盖 239.8 分钟。
- Argus PID `84290` 全程不变；无崩溃、无重启。
- CPU：avg 5.92%、median 5.90%、min 4.37%、P95 6.80%、max 7.30%；PRD §9 的 3 目标 ≤8% 通过。
- RSS：avg 102.3 MB、min 91.6 MB、max 122.9 MB、first 122.9 MB、last 94.2 MB；≤300 MB 且无持续增长。
- 相位：48/48 样本 `A=Streaming B=Streaming C=Streaming`；0 个 `NO_WINDOW`。
- 日志：`build/soak-20261122-161107.log`、`build/soak-cputime-20261122-final3.log`、`build/soak-phase-20261122-final3.log`。

CPU 路径：

- 448 px / 1 fps、3 目标 active OCR、Dashboard 前台可见 5 分钟 6.25%（`build/m4-cpu-448-5min-front.log`）。
- 512 px 5 分钟 7.86%；480 px 在 4h 前台可见条件下最近 5 分钟 8.24%；640 px 1 fps 8.15–8.30%；2 fps 11.7%；1.5 fps 7.9%。因此最终定 448 px / 1 fps。

真实豆包：

- 448 px 连续两次相同“只回复：收到”：第一次 `Idle→Streaming 1.07s→Settling 1.09s→Completed`；第二次 `Streaming 0.80s→Settling 1.06s→Completed`；无思考阶段误报。
- 证据：`build/doubao-448-two-repeats-20261122.log`。480 px 的两轮对照保留在 `build/doubao-480-two-repeats-20261122.log`。

隐私：

- PID 84290 时 `lsof -a -i` 无网络 socket；`~/Library/Application Support/Argus` 只有 `targets.json` 640 B；仓库 `build/` 近 5 小时无 PNG/JPG 帧文件。
- 日志只含窗口尺寸、ROI、状态与错误码，不含窗口标题、提示词或 OCR 正文。
- 证据：`build/m4-privacy-check-final-20261122.txt`。

FR-11 诊断页：

- 源码：`Sources/ArgusCore/Diagnostics/DiagnosticReport.swift`、`Sources/Argus/Diagnostics/DiagnosticsStore.swift`、`Sources/Argus/Diagnostics/DiagnosticsView.swift`。
- 实机：关闭 fixture A 后为 `UNKNOWN / windowClosed / D03_UNKNOWN`；点击该卡切窗按钮后为 `D04_ACTIVATION · Window activation failed`。
- 自动化：`DiagnosticsStoreTests` 覆盖 D01_NO_FRAMES 与 D07_SCREEN_RECORDING 的记录与脱敏；`swift test` 76 tests / 0 failures（56 ArgusCoreTests + 20 ArgusTests）。
- D07 未对主 App 做破坏性 TCC 重置；曾用临时 bundle 尝试，系统状态为 `notDetermined`，未进入 `denied`，主 App 授权未受影响。

通知运行时验证（2026-11-22）：

- 主 App 通知授权状态运行时读到 `authorized`（枚举值 2），无需再次弹窗。
- fixture A 绑定后经历 `Streaming→Settling→Completed`；进入 `Completed` 时 Argus 发出本地通知。
- 系统日志：`Adding notification request ... destinations: Default`；紧接 `Added notification request: [ hasError: 0 ]`。
- NotificationCenter 日志：`alertStyle: banner`，随后 `added to history`；因 `screencapture` 让显示器处于 `displayShared`，banner 与声音被系统静音（`muted by display state`）。因此屏幕截图里没有横幅，但通知确已投递并进入通知历史。
- 证据：`build/notify-runtime-20261122.log`。

已知边界（不阻塞 M4，进入后续迭代）：

- 窗口关闭/重开 50 次、显示器休眠/唤醒、锁屏/解锁、4 目标、多 Space/多显示器矩阵未穷举。
- D01/D07 只有单测覆盖，未做破坏性实机诱发。
- 448 px 对小字号/高 DPI 客户端的可读性只验证了豆包短回复；新 Profile 必须重新做 OCR 可读性验证。

## 未接线

- 真实客户端 Target Profile：豆包工作视觉 Profile 已接入并通过（`ReplyProfileRegistry.doubaoWork`）；AX 增强不可用；ChatGPT/Claude/Cursor 的 ROI、control ROI、settleDuration、阈值延后 M4；未知 bundle 继续回退 `ReplyProfile.generic`。
- 最小化窗口的 SCStream 行为（docs/02 开放问题，M4 soak 记录）。
- 签名、公证、DMG/ZIP 与内测分发（M5；bundle 已就绪，签名身份方案已定）。

## 下一步

1. 只做自用价值：真实使用观察、误报/漏报收集、按实际客户端加 Profile。
2. 通知已完成本机投递验证；换新机器或重置通知权限后，首次启动仍需在系统弹窗允许，拒绝后可在系统设置里重新开启。
3. 补窗口关闭/重开、显示器休眠/锁屏等按实际遇到的问题再修。
4. M5 签名/公证/分发继续冻结，等需要给第二台机器或他人使用时再开。

## 已拍板（2026-11-21）

- 单次最多监控 3 个目标；M4 soak 有数据后再评估放宽。
- 重启恢复严格不猜：同 bundle 只有唯一可用窗口才自动绑定，多候选一律 `NEEDS WINDOW` 交回用户。
- 首版客户端矩阵推到 M3 再定；M2 验收只要求任意真实窗口。
- 激活先匹配再激活；多候选或无候选不激活应用；AX 缺失只做应用级切换并明示降级（ADR-012）。
- 窗口关闭是恢复态不是终态：后台每 10 秒重试，严格唯一匹配才重绑；暂停目标不参与重建（M2c 默认）。
- `one-code` 仅作借鉴评估，2026-11-22 结论为暂不实施；先专注 Argus 自身，未来按 `docs/09` 的触发条件复核。未引入任何依赖或代码。
- M3 验收：接受“合成 fixture + 豆包工作真实视觉链路”；AX 增强与 ChatGPT/Claude/Cursor 标定延后 M4（2026-11-22）。

## 待拍板

- 完成检测的误报/漏报阈值与可接受延迟（M3 已按 owner 口径接受；正式 SLA 留 M4）。
- 多显示器 / Space 下激活优先级与行为（M2c/M4 实测，不猜）。
- ChatGPT/Claude/Cursor 矩阵是否作为 M4 退出条件。
- 是否走 Mac App Store；当前默认 Developer ID + 公证。
- 产品正式英文名/中文名是否保持 Argus。

## 证据

```text
swift build -> Build complete!
swift test  -> ArgusCoreTests 56 + ArgusTests 20 = 76 tests, 0 failures
               （M4 诊断：2 DiagnosticReport + 4 DiagnosticsStore）
./scripts/build-m3-fixtures.sh -> build/fixtures/Apps/A-D + PhaseSampler（ad-hoc 签名，无网络）
./scripts/make-app.sh -> build/Argus.app (com.bayernjf.argus, Authority=Argus Dev；M4 重建 2026-11-22)
M4 4h soak -> 16:11:07–20:11:25，480 samples；PID 84290 稳定；CPU avg 5.92%（median 5.90、p95 6.80、max 7.30）；
              RSS avg 102.3 MB（91.6–122.9）；48/48 相位 3/3 Streaming；0 NO_WINDOW
M4 CPU 448 -> 5 分钟前台可见 6.25%；512 7.86%；480 4h 稳态 8.24%；640 8.15–8.30%；2 fps 11.7%
M4 豆包 448 -> 两次“只回复：收到”均完成：Streaming 1.07→Settling 1.09→Completed；0.80→1.06→Completed
M4 diagnostics -> D03_UNKNOWN + D04_ACTIVATION 实机；D01/D07 DiagnosticsStoreTests；Copy 文本无窗口标题/OCR
M4 privacy -> 无网络 socket；Application Support 仅 targets.json；无 PNG/JPG；build/m4-privacy-check-final-20261122.txt
M3 正例 -> finish→Completed 上界 A 2.072s / B 1.865s / C 2.220s（/tmp/m3-positive-phases.log）
M3 负例 -> stallAx 4.002s 内始终 Streaming；static/blink 全程 Idle；无 Completed（/tmp/m3-negative-phases.log）
M3 UI -> /tmp/argus-m3-streaming-ui.png、/tmp/argus-m3-completed-ui.png
M3 布局 -> build/argus-m3-600.png / -900.png / -600-light.png / -900-light.png
M3 资源 -> 空闲约 11.7% CPU / 123MB；早期无条件 OCR 37.5%（已修）
M2c 布局烟测 -> 3 张假 bundle 的 NEEDS WINDOW 卡片（无真实窗口，未捕获任何用户内容）：
                 600×700 单列、状态条 4 项指标完整且提示隐藏；900×700 双列、提示显示；均无横向溢出。
                 截图 build/argus-m2c-3cards-600.png / -900.png（未提交）；演示 targets.json 已删除
M1 实机验收 -> 上述 2026-11-21 结果（截图取证 /tmp/argus-*.png，验收会话留存）
M2a 实机验收 -> 3 目标重启恢复、多窗口不猜、上限 3 均通过（见上方 §M2 实机验收结果）
M2b 实机验收 -> AX 精确 raise、未授权降级、重复标题 ambiguous、标题唯一精确切均通过；点击 10/10 为 97–115 ms
M2c 实机验收 -> WINDOW CLOSED/自动重建/暂停恢复/600/900 深浅色通过；30 分钟 soak 3 目标全程 LIVE
30 min soak -> 61 samples，CPU avg 12.3%（6.8–22.2%），RSS avg 120 MB（110–148 MB）；build/soak-20261121-235849.log
```

> 2026-11-21 事故记录：验收自动化期间误关了一个正在运行 `codebuddy` 的 Terminal 窗口（终止其 node 进程）；已向 owner 说明，重启 codebuddy 即可恢复。教训：窗口自动化只操作自建窗口。
