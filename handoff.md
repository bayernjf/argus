# handoff — Argus

- 更新日期：2026-11-21
- 当前阶段：M1 代码完成（M1a/M1b/M1c），待实机验收
- Tier：2

## 当前状态

- 仓库骨架：Swift Package，`ArgusCore` library + `Argus` executable + `ArgusCoreTests`；Package.swift 已升到 swift-tools 6.0（Swift 6 语言模式，与 AGENTS.md 对齐）。
- UI：SwiftUI Dashboard 接入 `DashboardStore`（@MainActor @Observable，docs/02 预定模块）；「Add target」打开 `WindowPickerSheet`；卡片显示真实窗口信息，缩略图仍为占位（标注 M1c）。
- M1a `.app` bundle：`scripts/make-app.sh` 组装 `build/Argus.app`（bundle id `com.bayernjf.argus`，Info.plist 含 `NSScreenCaptureUsageDescription`；优先使用本机自签 `Argus Dev` 身份，缺失时回退 ad-hoc，`ARGUS_SIGN_IDENTITY` 可覆盖）。
- M1b 窗口枚举与权限：`WindowEnumerator`（SCShareableContent → `CaptureWindowInfo` 过滤）+ `PermissionManager`（CGPreflight/CGRequest，激活时热更新）；被拒时 picker 内提供「Open System Settings」+「Retry」，不崩溃。
- M1c 真实帧捕获：`ScreenCaptureSession`（`SCContentFilter(desktopIndependentWindow:)`、2 fps、960 宽比例输出、queueDepth 3、仅内存保留最新帧）；`DashboardStore` 管会话生命周期并以 250ms 轮询把帧喂给卡片；卡片显示 LIVE · 2 FPS / CONNECTING / CAPTURE ERROR 状态；窗口关闭通过 `CGWindowList` 复核转为失败态，权限撤销以失败态呈现，不崩溃。
- 核心逻辑：`ReplyPhase` / `ReplyActivity` / `ReplyCompletionDetector`；新增 `CaptureWindowInfo` 过滤与 `TargetApplication` 映射（纯逻辑，6 个单测覆盖）。
- 文档：docs/07 bundle id 已确认；docs/03 M1 状态改为进行中。

## 未接线

- OCR / Accessibility / 帧差信号提取（M3）。
- 点击缩略图激活目标窗口（M2）。
- 目标列表本地持久化、暂停/恢复、资源上限（M2；已加最小的卡片右键 Remove）。
- 会话自动重建（窗口关闭后需手动重新添加，M2）。
- 最小化窗口的 SCStream 行为（docs/02 开放问题，待实机记录）。
- 签名、公证、DMG/ZIP 与内测分发（M5；本轮仅最小 bundle）。

## 下一步

1. M1b/M1c 实机验收（下方清单）→ 修正暴露的问题。
2. M2：多目标协调、点击切换、持久化。

## 待拍板

- 首版支持哪些 macOS AI 客户端（M1 验收对象已定 ChatGPT，Claude/Cursor 备用）。
- 单次最多同时监控多少个目标。
- 完成检测的误报/漏报阈值与可接受延迟。
- 多窗口/多实例时卡片如何绑定目标窗口。
- 是否走 Mac App Store；当前默认 Developer ID + 公证。
- `one-code` 可复用模块边界与许可证。
- 产品正式英文名/中文名是否保持 Argus。

## 证据

```text
swift build -> Build complete!
swift test  -> Executed 13 tests, with 0 failures（新增 6 个 CaptureWindowInfo 单测）
./scripts/make-app.sh -> build/Argus.app (com.bayernjf.argus)
codesign -dv build/Argus.app -> Identifier=com.bayernjf.argus, Authority=Argus Dev
```

> 2026-11-21 补充：2 FPS、窗口关闭复核、无障碍标签与稳定签名改动已通过 `swift build`、`swift test` 与本机 `make-app.sh`；真实捕获的交互验收仍待 owner 按下方清单执行。

## 手工验收清单（M1，待 owner 实机执行）

1. `open build/Argus.app` → 点「Add target」→ 首次弹出屏幕录制授权框。
2. 拒绝 → Argus 不崩溃，picker 显示引导 + 「Open System Settings」可跳转。
3. 授予 → 窗口列表出现真实窗口（预期含 ChatGPT）→ 选中 → 卡片显示真实应用名/窗口标题。
4. M1c：选中窗口后 2 秒内卡片出现真实画面（退出条件：首帧 ≤ 2s）。
5. M1c：目标窗口内容变化后 ≤ 1 秒缩略图更新；卡片角标显示 LIVE · 2 FPS。
6. M1c：关闭目标窗口 → 卡片转 CAPTURE ERROR（附原因），不崩溃。
7. 系统设置撤销权限 → 切回 Argus → 状态热更新为 denied。
8. 最小化目标窗口 → 记录卡片表现（首帧停止/无新帧），不崩溃。
9. 对照实验：`swift run Argus` 裸跑时权限/枚举身份不正确（验证 R-10）。
10. 卡片右键 Remove 可移除目标；退出 Argus 后无残留进程、无落盘文件。

注意：本机已有 `Argus Dev` 自签身份时脚本会自动使用，TCC 授权可跨重建保留；换机器或证书丢失时脚本回退 ad-hoc，需按 `scripts/make-app.sh` 头部注释重建证书，或显式传 `ARGUS_SIGN_IDENTITY`。
