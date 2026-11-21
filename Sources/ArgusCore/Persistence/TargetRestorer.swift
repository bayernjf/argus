import Foundation

/// Why a persisted target could not be bound to a window on this launch.
/// The dashboard shows a "Re-select window" path for every case except
/// `permissionRequired`, which resolves itself once Screen Recording is
/// granted.
public enum TargetRestoreIssue: String, Equatable, Sendable {
    case missingBundleIdentifier
    case noEligibleWindow
    case ambiguousWindows
    case windowAlreadyClaimed
    case permissionRequired
}

public struct RestoredTarget: Equatable, Sendable {
    public let record: PersistedTarget
    public let window: CaptureWindowInfo

    public init(record: PersistedTarget, window: CaptureWindowInfo) {
        self.record = record
        self.window = window
    }
}

public struct UnresolvedTarget: Equatable, Sendable {
    public let record: PersistedTarget
    public let issue: TargetRestoreIssue
    public let candidateCount: Int

    public init(record: PersistedTarget, issue: TargetRestoreIssue, candidateCount: Int) {
        self.record = record
        self.issue = issue
        self.candidateCount = candidateCount
    }
}

public enum TargetRestoreOutcome: Equatable, Sendable {
    case restored(RestoredTarget)
    case unresolved(UnresolvedTarget)
}

public struct TargetRestoration: Equatable, Sendable {
    public let outcomes: [TargetRestoreOutcome]

    public init(outcomes: [TargetRestoreOutcome]) {
        self.outcomes = outcomes
    }

    public var restored: [RestoredTarget] {
        outcomes.compactMap {
            if case .restored(let target) = $0 { return target }
            return nil
        }
    }

    public var unresolved: [UnresolvedTarget] {
        outcomes.compactMap {
            if case .unresolved(let target) = $0 { return target }
            return nil
        }
    }
}

/// Restores persisted targets without guessing (owner decision 2026-11-21).
///
/// Binding rules:
/// - an empty bundle id never binds;
/// - exactly one free eligible window with the same bundle id binds it;
/// - two or more candidates stay unresolved, even if one title matches —
///   chat window titles change with the conversation, so a title is a hint;
/// - a window already claimed by an earlier record is not reused for another.
///
/// Order is preserved so cards come back where they were.
public enum TargetRestorer {
    public static func restore(
        _ records: [PersistedTarget],
        against windows: [CaptureWindowInfo]
    ) -> TargetRestoration {
        var claimed: Set<UInt32> = []
        var outcomes: [TargetRestoreOutcome] = []
        outcomes.reserveCapacity(records.count)

        for record in records {
            let bundle = record.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bundle.isEmpty else {
                outcomes.append(.unresolved(
                    UnresolvedTarget(record: record, issue: .missingBundleIdentifier, candidateCount: 0)
                ))
                continue
            }

            let candidates = windows.filter { $0.appBundleIdentifier == bundle }
            let free = candidates.filter { !claimed.contains($0.id) }

            switch free.count {
            case 1:
                let window = free[0]
                claimed.insert(window.id)
                outcomes.append(.restored(RestoredTarget(record: record, window: window)))
            case 0:
                let issue: TargetRestoreIssue = candidates.isEmpty ? .noEligibleWindow : .windowAlreadyClaimed
                outcomes.append(.unresolved(
                    UnresolvedTarget(record: record, issue: issue, candidateCount: candidates.count)
                ))
            default:
                outcomes.append(.unresolved(
                    UnresolvedTarget(record: record, issue: .ambiguousWindows, candidateCount: free.count)
                ))
            }
        }

        return TargetRestoration(outcomes: outcomes)
    }
}
