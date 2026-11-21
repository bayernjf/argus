# handoff — Argus

- 更新日期：2026-11-21
- 当前阶段：M1 进行中（M1a/M1b 完成，M1c 待做）
- Tier：2

## 当前状态

- 仓库骨架：Swift Package，`ArgusCore` library + `Argus` executable + `ArgusCoreTests`；Package.swift 已升到 swift-tools 6.0（Swift 6 语言模式，与 AGENTS.md 对齐）。
- UI：SwiftUI Dashboard 接入 `DashboardStore`（@MainActor @Observable，docs/02 预定模块）；「Add target」打开 `WindowPickerSheet`；卡片显示真实窗口信息，缩略图仍为占位（标注 M1c）。
- M1a `.app` bundle：`scripts/make-app.sh` 组装 `build/Argus.app`（bundle id `com.bayernjf.argus`，Info.plist 含 `NSScreenCaptureUsageDescription`，ad-hoc 签名，`ARGUS_SIGN_IDENTITY` 可覆盖）。
- M1b 窗口枚举与权限：`WindowEnumerator`（SCShareableContent → `CaptureWindowInfo` 过滤）+ `PermissionManager`（CGPreflight/CGRequest，激活时热更新）；被拒时 picker 内提供「Open System Settings」+「Retry」，不崩溃。
- 核心逻辑：`ReplyPhase` / `ReplyActivity` / `ReplyCompletionDetector`；新增 `CaptureWindowInfo` 过滤与 `TargetApplication` 映射（纯逻辑，6 个单测覆盖）。
- 文档：docs/07 bundle id 已确认；docs/03 M1 状态改为进行中。

## 未接线

- M1c：SCStream 真实帧捕获、1 fps 缩略图、窗口关闭/最小化的失败态。
- OCR / Accessibility / 帧差信号提取（M3）。
- 点击缩略图激活目标窗口（M2）。
- 目标列表本地持久化、暂停/恢复、资源上限（M2；本轮已加最小的卡片右键 Remove）。
- 签名、公证、DMG/ZIP 与内测分发（M5；本轮仅最小 bundle）。

## 下一步

1. M1c：`WindowCaptureSession`（SCContentFilter(desktopIndependentWindow:)、1 fps、320×180）接进真实卡片，补失败态。
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
codesign -dv build/Argus.app -> Identifier=com.bayernjf.argus, Signature=adhoc
```

## 手工验收清单（M1b，待 owner 实机执行）

1. `open build/Argus.app` → 点「Add target」→ 首次弹出屏幕录制授权框。
2. 拒绝 → Argus 不崩溃，picker 显示引导 + 「Open System Settings」可跳转。
3. 授予 → 窗口列表出现真实窗口（预期含 ChatGPT）→ 选中 → 卡片显示真实应用名/窗口标题。
4. 系统设置撤销权限 → 切回 Argus → 状态热更新为 denied。
5. 对照实验：`swift run Argus` 裸跑时权限/枚举身份不正确（验证 R-10）。
6. 卡片右键 Remove 可移除目标。

注意：ad-hoc 签名每次重建 CDHash 变化，TCC 可能要求重新授权；反复弹权限时按 `scripts/make-app.sh` 头部注释创建自签证书并用 `ARGUS_SIGN_IDENTITY` 签名。
