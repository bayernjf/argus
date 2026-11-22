import Foundation
@preconcurrency import UserNotifications

/// Local-only completion notifications. The notification carries the target
/// app's display name only; window titles, OCR text and screenshots never
/// enter the notification payload.
@MainActor
protocol ReplyNotifying: AnyObject {
    func prepare() async
    func notifyCompleted(displayName: String, at date: Date)
}

/// The only notification payload Argus builds. Keeping this separate makes
/// the privacy boundary testable: no window title or OCR text can enter it.
struct ReplyNotificationMessage: Equatable, Sendable {
    let title: String
    let body: String

    static func completed(displayName: String) -> Self {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self(
            title: "回复完成",
            body: "\(name.isEmpty ? "目标" : name) 已完成回复"
        )
    }
}

@MainActor
final class ReplyNotifier: ReplyNotifying {
    private let center: UNUserNotificationCenter
    private var canNotify = false

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func prepare() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            canNotify = true
        case .notDetermined:
            do {
                canNotify = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                canNotify = false
            }
        default:
            canNotify = false
        }
    }

    func notifyCompleted(displayName: String, at date: Date) {
        guard canNotify else { return }

        let message = ReplyNotificationMessage.completed(displayName: displayName)
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.threadIdentifier = "argus.reply-completed"

        let request = UNNotificationRequest(
            identifier: "completed-\(Int(date.timeIntervalSince1970))-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        Task {
            try? await center.add(request)
        }
    }
}
