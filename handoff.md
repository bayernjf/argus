# handoff — Argus

- 更新日期：2026-11-21
- 当前阶段：M2 已完成并通过实机验收（含 3 目标 30 分钟 soak、点击切窗时延、600/900 深浅色）；M1 已完成；M3 未开始
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
- 文档：docs/03 M2 标记进行中；docs/04 FR-06/07 更新为 in_progress；docs/05 新增 ADR-013（窗口关闭可恢复、暂停冻结最后一帧）；docs/06 证据刷新到 M2c；docs/08 R-07/R-08 状态更新；docs/07 bundle id 已确认。

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
- `CONNECTING` 阶段暂停未稳定复现（AX 按钮在状态切换后重建，批量点击只命中第一次）；未计入通过，留作 M4 回归项。

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

## 未接线

- OCR / Accessibility 控件信号 / 帧差提取（M3；AX 目前只用于窗口切换，不参与检测）。
- 最小化窗口的 SCStream 行为（docs/02 开放问题，M4 soak 记录）。
- 签名、公证、DMG/ZIP 与内测分发（M5；bundle 已就绪，签名身份方案已定）。

## 下一步

1. 跑 M2a / M2b / M2c 三份实机清单（上方），把结果补进本文件；AX 真实切窗必须人工授权后测。
2. 用 `scripts/soak.sh 30` 完成 3 目标 30 分钟 soak，填 CPU/RSS 与错绑记录。
3. M2 收口后更新 docs/06 手工矩阵与 handoff 证据，再进 M3。

## 已拍板（2026-11-21）

- 单次最多监控 3 个目标；M4 soak 有数据后再评估放宽。
- 重启恢复严格不猜：同 bundle 只有唯一可用窗口才自动绑定，多候选一律 `NEEDS WINDOW` 交回用户。
- 首版客户端矩阵推到 M3 再定；M2 验收只要求任意真实窗口。
- 激活先匹配再激活；多候选或无候选不激活应用；AX 缺失只做应用级切换并明示降级（ADR-012）。
- 窗口关闭是恢复态不是终态：后台每 10 秒重试，严格唯一匹配才重绑；暂停目标不参与重建（M2c 默认）。

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
                 M2b 7：WindowMatchPolicy；M2c 未新增纯逻辑单测）
./scripts/make-app.sh -> build/Argus.app (com.bayernjf.argus, Authority=Argus Dev；修复后重新打包 2026-11-21 23:5x)
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
