import Foundation

/// Never restore an old clipboard over something the user copied during insertion.
public enum ClipboardPolicy {
    /// These desktop composers acknowledge selected-text writes without applying them.
    /// Choose one insertion method up front; never paste after an ambiguous direct write.
    public static func prefersPaste(appID: String) -> Bool {
        ["com.openai.codex", "com.openai.chat"].contains(appID)
    }

    public static func shouldRestore(ownedChangeCount: Int, currentChangeCount: Int) -> Bool {
        ownedChangeCount == currentChangeCount
    }
    public static func canSnapshot(sizes: [Int], limit: Int = 16 * 1024 * 1024) -> Bool {
        var total = 0
        for size in sizes {
            guard size >= 0, size <= limit - total else { return false }
            total += size
        }
        return true
    }
}
