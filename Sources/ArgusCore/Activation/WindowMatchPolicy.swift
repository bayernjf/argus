import Foundation

/// Which AX window should be raised for a card.
public enum WindowMatch: Equatable, Sendable {
    case unique(index: Int)
    case ambiguous(count: Int)
    case none
}

/// Pure identity rule for window activation (ADR-012).
///
/// - One window in the app: use it, mirroring docs/02 §5.1 fallback.
/// - Several windows: only an exact (whitespace-trimmed) title match binds;
///   zero or multiple matches stay unresolved instead of guessing.
/// - Empty titles never disambiguate several windows.
public enum WindowMatchPolicy {
    public static func match(targetTitle: String, candidateTitles: [String]) -> WindowMatch {
        guard !candidateTitles.isEmpty else { return .none }
        if candidateTitles.count == 1 { return .unique(index: 0) }

        let target = targetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return .none }

        let matches = candidateTitles.enumerated().filter { _, title in
            title.trimmingCharacters(in: .whitespacesAndNewlines) == target
        }
        switch matches.count {
        case 1:
            return .unique(index: matches[0].offset)
        case 0:
            return .none
        default:
            return .ambiguous(count: matches.count)
        }
    }
}
